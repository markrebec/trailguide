module TrailGuide
  class Participant
    attr_reader :context
    delegate :key?, :keys, :[], :[]=, :delete, :destroy!, :to_h, to: :adapter

    def initialize(context, adapter: nil)
      @context = context
      @adapter = adapter.new(context) if adapter.present?

      @participating = {}
      @converted = {}
      @variant = {}

      cleanup_inactive_experiments! if TrailGuide.configuration.cleanup_participant_experiments == true
    end

    def adapter
      @adapter ||= begin
        config_adapter = TrailGuide.configuration.adapter
        case config_adapter
        when :cookie
          config_adapter = TrailGuide::Adapters::Participants::Cookie
        when :session
          config_adapter = TrailGuide::Adapters::Participants::Session
        when :redis
          config_adapter = TrailGuide::Adapters::Participants::Redis
        when :anonymous
          config_adapter = TrailGuide::Adapters::Participants::Anonymous
        when :multi
          config_adapter = TrailGuide::Adapters::Participants::Multi
        else
          config_adapter = config_adapter.constantize if config_adapter.is_a?(String)
        end
        config_adapter.new(context)
      rescue => e
        [TrailGuide.configuration.on_adapter_failover].flatten.compact.each do |callback|
          callback.call(config_adapter, e)
        end
        TrailGuide::Adapters::Participants::Anonymous.new(context)
      end
    end

    def variant(experiment)
      return nil unless experiment.calibrating? || experiment.started?
      return nil unless adapter.key?(experiment.storage_key)
      varname = adapter[experiment.storage_key]
      variant = experiment.variants.find { |var| var == varname }
      return nil unless variant && adapter.key?(variant.storage_key)

      chosen_at = Time.at(adapter[variant.storage_key].to_i)
      started_at = experiment.started_at
      return @variant[experiment.storage_key] = variant if (variant.control? && experiment.calibrating?) || (started_at && chosen_at >= started_at)
    end

    def participating?(experiment, include_control=true)
      return @participating[experiment.storage_key] if @participating.key?(experiment.storage_key)

      var = variant(experiment)
      return @participating[experiment.storage_key] = false if var.nil?
      return @participating[experiment.storage_key] = false if !include_control && var.control?
      return @participating[experiment.storage_key] = true
    end

    def converted?(experiment, checkpoint=nil)
      variant = variant(experiment)

      return false unless experiment.started? || (experiment.calibrating? && variant.try(:control?))

      if experiment.goals.empty?
        raise InvalidGoalError, "You provided the checkpoint `#{checkpoint}` but the experiment `#{experiment.experiment_name}` does not have any goals defined." unless checkpoint.nil?
        storage_key = "#{experiment.storage_key}:converted"
        return @converted[experiment.storage_key][storage_key] if @converted.key?(experiment.storage_key) && @converted[experiment.storage_key].key?(storage_key)
        return false unless adapter.key?(storage_key)

        converted_at = Time.at(adapter[storage_key].to_i)
        (experiment.calibrating? && variant.try(:control?)) || converted_at >= experiment.started_at
      elsif !checkpoint.nil?
        goal = experiment.goals.find { |g| g == checkpoint }
        raise InvalidGoalError, "Invalid goal checkpoint `#{checkpoint}` for experiment `#{experiment.experiment_name}`." if goal.nil?
        return @converted[experiment.storage_key][goal.storage_key] if @converted.key?(experiment.storage_key) && @converted[experiment.storage_key].key?(goal.storage_key)
        return false unless adapter.key?(goal.storage_key)

        converted_at = Time.at(adapter[goal.storage_key].to_i)
        (experiment.calibrating? && variant.try(:control?)) || converted_at >= experiment.started_at
      else
        experiment.goals.each do |goal|
          return true if @converted.key?(experiment.storage_key) && @converted[experiment.storage_key][goal.storage_key] == true
          next unless adapter.key?(goal.storage_key)
          converted_at = Time.at(adapter[goal.storage_key].to_i)
          return true if (experiment.calibrating? && variant.try(:control?)) || converted_at >= experiment.started_at
        end
        return false
      end
    end

    def participating!(variant)
      @participating[variant.experiment.storage_key] = true
      adapter[variant.experiment.storage_key] = variant.name
      adapter[variant.storage_key] = Time.now.to_i
    end

    def converted!(variant, checkpoint=nil, reset: false)
      if checkpoint.nil?
        storage_key = "#{variant.experiment.storage_key}:converted"
      else
        storage_key = variant.experiment.goals.find { |g| g == checkpoint }.storage_key
      end

      if reset
        adapter.delete(variant.experiment.storage_key)
        adapter.delete(variant.storage_key)
        adapter.delete(storage_key)
        variant.experiment.goals.each do |goal|
          adapter.delete(goal.storage_key)
        end
      else
        @converted[variant.experiment.storage_key] ||= {}
        @converted[variant.experiment.storage_key][storage_key] = true
        adapter[storage_key] = Time.now.to_i
      end
    end

    def exit!(experiment)
      @participating.delete(experiment.storage_key)
      @converted.delete(experiment.storage_key)
      @variant.delete(experiment.storage_key)

      chosen = variant(experiment)
      return true if chosen.nil?
      adapter.delete(experiment.storage_key)
      adapter.delete(chosen.storage_key)
      adapter.delete("#{experiment.storage_key}:converted")
      experiment.goals.each do |goal|
        adapter.delete(goal.storage_key)
      end
      return true
    end

    def active_experiments(include_control=true)
      return false if adapter.keys.empty?

      inactive = []
      active = adapter.keys.map { |key| key.to_s.split(":").first.to_sym }.uniq.map do |key|
        experiment = TrailGuide.catalog.find(key)
        next unless experiment
        next unless experiment.configuration.sticky_assignment?

        if !experiment.started? && !experiment.calibrating?
          inactive << key
          next
        else
          next unless !experiment.combined? && experiment.running? && participating?(experiment, include_control)
          [ experiment.experiment_name, adapter[experiment.storage_key] ]
        end
      end.compact.to_h

      if TrailGuide.configuration.cleanup_participant_experiments == :inline && !inactive.empty?
        adapter.keys.select do |key|
          inactive.include?(key.to_s.split(":").first.to_sym)
        end.each { |key| adapter.delete(key) }
      end

      return active
    end

    def calibrating_experiments
      return false if adapter.keys.empty?

      adapter.keys.map { |key| key.to_s.split(":").first.to_sym }.uniq.map do |key|
        experiment = TrailGuide.catalog.find(key)
        next unless experiment && experiment.calibrating?
        [ experiment.experiment_name, adapter[experiment.storage_key] ]
      end.compact.to_h
    end

    def participating_in_active_experiments?(include_control=true)
      return false if adapter.keys.empty?

      adapter.keys.any? do |key|
        experiment_name = key.to_s.split(":").first.to_sym
        experiment = TrailGuide.catalog.find(experiment_name)
        experiment && experiment.configuration.sticky_assignment? && !experiment.combined? && experiment.running? && participating?(experiment, include_control)
      end
    end

    def cleanup_inactive_experiments!
      return false if adapter.keys.empty?

      adapter.keys.each do |key|
        experiment_name = key.to_s.split(":").first.to_sym
        experiment = TrailGuide.catalog.find(experiment_name)
        if !experiment || (!experiment.started? && !experiment.calibrating?)
          adapter.delete(key)
        end
      end

      return true
    end
  end
end
