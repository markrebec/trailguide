module TrailGuide
  class Experiment
    class << self
      def inherited(child)
        # TODO allow inheriting algo, variants, goals, metrics, etc.
        TrailGuide::Catalog.register(child)
      end

      # TODO could probably move all this configuration stuff at the class level
      # into a canfig object instead...?
      def experiment_name(name=nil)
        @experiment_name = name.to_s.underscore.to_sym unless name.nil?
        @experiment_name || self.name.try(:underscore).try(:to_sym)
      end

      def algorithm(algo=nil)
        @algorithm = algo unless algo.nil?
        @algorithm ||= TrailGuide.configuration.algorithm
      end

      def resettable(reset)
        @resettable = reset
      end

      def resettable?
        if @resettable.nil?
          !TrailGuide.configuration.reset_manually
        else
          !!@resettable
        end
      end

      def variant(name, metadata: {}, weight: 1, control: false)
        raise ArgumentError, "The variant #{name} already exists in experiment #{experiment_name}" if variants.any? { |var| var == name }
        control = true if variants.empty?
        variant = Variant.new(self, name, metadata: metadata, weight: weight, control: control)
        variants << variant
        variant
      end

      def variants(include_control=true)
        @variants ||= []
        if include_control
          @variants
        else
          @variants.select { |var| !var.control? }
        end
      end

      def control(name=nil)
        return variants.find { |var| var.control? } || variants.first if name.nil?

        variants.each(&:variant!)
        var_idx = variants.index { |var| var == name }

        if var_idx.nil?
          variant = Variant.new(self, name, control: true)
        else
          variant = variants.slice!(var_idx, 1)[0]
          variant.control!
        end

        variants.unshift(variant)
        return variant
      end

      def funnel(name)
        funnels << name.to_s.underscore.to_sym
      end
      alias_method :goal, :funnel

      def funnels(arr=nil)
        @funnels = arr unless arr.nil?
        @funnels ||= []
      end
      alias_method :goals, :funnels

      def metric(key=nil)
        @metric = key.to_s.underscore.to_sym unless key.nil?
        @metric ||= experiment_name
      end

      def allow_multiple_conversions(allow)
        @allow_multiple_conversions = allow
      end

      def allow_multiple_conversions?
        !!@allow_multiple_conversions
      end

      def allow_multiple_goals(allow)
        @allow_multiple_goals = allow
      end

      def allow_multiple_goals?
        !!@allow_multiple_goals
      end

      def start!
        return false if started?
        save! unless persisted?
        TrailGuide.redis.hset(storage_key, 'started_at', Time.now.to_i)
      end

      def stop!
        return false unless started?
        TrailGuide.redis.hdel(storage_key, 'started_at')
      end

      def started_at
        started = TrailGuide.redis.hget(storage_key, 'started_at')
        return Time.at(started.to_i) if started
      end

      def started?
        !!started_at
      end

      def declare_winner!(variant)
        variant = variant.name if variant.is_a?(Variant)
        TrailGuide.redis.hset(storage_key, 'winner', variant.to_s.underscore)
      end

      def winner
        winner = TrailGuide.redis.hget(storage_key, 'winner')
        return variants.find { |var| var == winner } if winner
      end

      def winner?
        !!winner
      end

      def persisted?
        TrailGuide.redis.exists(storage_key)
      end

      def save!
        variants.each(&:save!)
        TrailGuide.redis.hsetnx(storage_key, 'name', experiment_name)
      end

      def delete!
        variants.each(&:delete!)
        TrailGuide.redis.del(storage_key)
        # TODO also clear out stats, etc.
      end

      def reset!
        delete! && save!
      end

      def as_json(opts={})
        # TODO fill in the rest of the values i've added
        {
          experiment_name: experiment_name,
          algorithm: algorithm,
          variants: variants.as_json
        }
      end

      def storage_key
        experiment_name
      end
    end

    attr_reader :participant
    delegate :experiment_name, :variants, :control, :funnels, :storage_key,
      :started?, :started_at, :start!, :resettable?, :winner?, :winner,
      :allow_multiple_conversions?, :allow_multiple_goals?, to: :class

    def initialize(participant)
      @participant = participant
    end

    def algorithm
      @algorithm ||= self.class.algorithm.new(self)
    end

    def excluded?
      false # TODO maybe at the context helper/proxy level?
    end

    def choose!(override: nil)
      return control if TrailGuide.configuration.disabled
      if override.present?
        variant = variants.find { |var| var == override }
        return variant unless TrailGuide.configuration.store_override
      else
        return winner if winner?
        return control if excluded?
        return control if !started? && TrailGuide.configuration.start_manually
        start! unless started?
        return variants.find { |var| var == participant[storage_key] } if participating?
        return control unless TrailGuide.configuration.allow_multiple_experiments == true || !participant.participating_in_active_experiments?(TrailGuide.configuration.allow_multiple_experiments == false) 

        variant = algorithm.choose!
      end

      participant.participating!(variant)
      variant.increment_participation!
      variant
    end

    def convert!(checkpoint=nil)
      return false unless participating?
      raise ArgumentError, "You must provide a valid goal checkpoint for #{experiment_name}" unless checkpoint.present? || funnels.empty?
      raise ArgumentError, "Unknown goal checkpoint: #{checkpoint}" unless checkpoint.nil? || funnels.any? { |funnel| funnel == checkpoint.to_s.underscore.to_sym }
      # TODO eventually allow progressing through funnel checkpoints towards goals
      if converted?(checkpoint)
        return false unless allow_multiple_conversions?
      elsif converted?
        return false unless allow_multiple_goals?
      end

      variant = variants.find { |var| var == participant[storage_key] }
      # TODO eventually only reset if we're at the final goal in a funnel
      participant.converted!(variant, checkpoint, reset: resettable?)
      variant.increment_conversion!(checkpoint)
      variant
    end

    def participating?
      participant.participating?(self)
    end

    def converted?(checkpoint=nil)
      participant.converted?(self, checkpoint)
    end
  end
end
