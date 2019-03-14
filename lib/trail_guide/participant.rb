module TrailGuide
  class Participant
    attr_reader :adapter
    delegate :key?, :keys, :[], :[]=, :delete, :destroy!, :to_h, to: :adapter

    def initialize(context, adapter: nil)
      @adapter = adapter.present? ? adapter.new(context) : configured_adapter.new(context)
      #cleanup_inactive_experiments!
    end

    def configured_adapter
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
      config_adapter
    rescue => e
      [TrailGuide.configuration.on_adapter_failover].flatten.compact.each do |callback|
        callback.call(config_adapter, e)
      end
      TrailGuide::Adapters::Participants::Anonymous
    end

    def participating?(experiment, include_control=true)
      return false unless experiment.started?
      return false unless adapter.key?(experiment.storage_key)
      varname = adapter[experiment.storage_key]
      variant = experiment.variants.find { |var| var == varname }
      return false if !include_control && variant.control?
      return false unless variant && adapter.key?(variant.storage_key)

      chosen_at = Time.at(adapter[variant.storage_key].to_i)
      return variant if chosen_at >= experiment.started_at
    end

    def converted?(experiment, checkpoint=nil)
      return false unless experiment.started?
      if experiment.goals.empty?
        raise InvalidGoalError, "You provided the checkpoint `#{checkpoint}` but the experiment `#{experiment.experiment_name}` does not have any goals defined." unless checkpoint.nil?
        storage_key = "#{experiment.storage_key}:converted"
        return false unless adapter.key?(storage_key)

        converted_at = Time.at(adapter[storage_key].to_i)
        converted_at >= experiment.started_at
      elsif !checkpoint.nil?
        raise InvalidGoalError, "Invalid goal checkpoint `#{checkpoint}` for experiment `#{experiment.experiment_name}`." unless experiment.goals.any? { |goal| goal == checkpoint.to_s.underscore.to_sym }
        storage_key = "#{experiment.storage_key}:#{checkpoint.to_s.underscore}"
        return false unless adapter.key?(storage_key)

        converted_at = Time.at(adapter[storage_key].to_i)
        converted_at >= experiment.started_at
      else
        experiment.goals.each do |goal|
          storage_key = "#{experiment.storage_key}:#{goal.to_s}"
          next unless adapter.key?(storage_key)
          converted_at = Time.at(adapter[storage_key].to_i)
          return true if converted_at >= experiment.started_at
        end
        return false
      end
    end

    def variant(experiment)
      participating?(experiment) || nil
    end

    def participating!(variant)
      adapter[variant.experiment.storage_key] = variant.name
      adapter[variant.storage_key] = Time.now.to_i
    end

    def converted!(variant, checkpoint=nil, reset: false)
      checkpoint ||= :converted
      storage_key = "#{variant.experiment.storage_key}:#{checkpoint.to_s.underscore}"

      if reset
        adapter.delete(variant.experiment.storage_key)
        adapter.delete(variant.storage_key)
        adapter.delete(storage_key)
        variant.experiment.goals.each do |goal|
          goal_key = "#{variant.experiment.storage_key}:#{goal.to_s}"
          adapter.delete(goal_key)
        end
      else
        adapter[storage_key] = Time.now.to_i
      end
    end

    def exit!(experiment)
      chosen = variant(experiment)
      return true if chosen.nil?
      adapter.delete(experiment.storage_key)
      adapter.delete(chosen.storage_key)
      experiment.goals.each do |goal|
        adapter.delete("#{experiment.storage_key}:#{goal.to_s}")
      end
      return true
    end

    def active_experiments(include_control=true)
      return false if adapter.keys.empty?
      adapter.keys.map { |key| key.to_s.split(":").first.to_sym }.uniq.map do |key|
        experiment = TrailGuide.catalog.find(key)
        next unless experiment && !experiment.combined? && experiment.running? && participating?(experiment, include_control)
        [ experiment.experiment_name, adapter[experiment.storage_key] ]
      end.compact.to_h
    end

    def participating_in_active_experiments?(include_control=true)
      return false if adapter.keys.empty?

      adapter.keys.any? do |key|
        experiment_name = key.to_s.split(":").first.to_sym
        experiment = TrailGuide.catalog.find(experiment_name)
        experiment && !experiment.combined? && experiment.running? && participating?(experiment, include_control)
      end
    end

    def cleanup_inactive_experiments!
      return false if adapter.keys.empty?

      adapter.keys.each do |key|
        experiment_name = key.to_s.split(":").first.to_sym
        experiment = TrailGuide.catalog.find(experiment_name)
        if !experiment || !experiment.started?
          adapter.delete(key)
        end
      end

      return true
    end
  end
end
