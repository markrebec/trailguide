require "trail_guide/experiment_config"

module TrailGuide
  class Experiment
    class << self
      delegate :metric, :algorithm, :control, :goals, :callbacks,
        :allow_multiple_conversions?, :allow_multiple_goals?, to: :configuration
      alias_method :funnels, :goals

      def inherited(child)
        TrailGuide::Catalog.register(child)
      end

      def configuration
        @configuration ||= ExperimentConfig.new(self)
      end

      def configure(*args, &block)
        configuration.configure(*args, &block)
      end

      def resettable?
        !configuration.reset_manually
      end

      def experiment_name
        configuration.name
      end

      def variants(include_control=true)
        if include_control
          configuration.variants
        else
          configuration.variants.select { |var| !var.control? }
        end
      end

      def run_callbacks(hook, *args)
        return unless callbacks[hook]
        args.unshift(self)
        callbacks[hook].each do |callback|
          if callback.respond_to?(:call)
            callback.call(*args)
          else
            send(callback, *args)
          end
        end
      end

      def start!
        return false if started?
        save! unless persisted?
        started = TrailGuide.redis.hset(storage_key, 'started_at', Time.now.to_i)
        run_callbacks(:on_start)
        started
      end

      def stop!
        return false unless started?
        stopped = TrailGuide.redis.hdel(storage_key, 'started_at')
        run_callbacks(:on_stop)
        stopped
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
        TrailGuide.redis.hexists(storage_key, 'winner')
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
        deleted = TrailGuide.redis.del(storage_key)
        run_callbacks(:on_delete)
        deleted
      end

      def reset!
        reset = (delete! && save!)
        run_callbacks(:on_reset)
        reset
      end

      def as_json(opts={})
        { experiment_name => {
          configuration: {
            metric: metric,
            algorithm: algorithm.name,
            variants: variants.as_json,
            goals: goals.as_json,
            resettable: resettable?,
            allow_multiple_conversions: allow_multiple_conversions?,
            allow_multiple_goals: allow_multiple_goals?
          },
          statistics: {
            # TODO expand on this for variants/goals
            participants: variants.sum(&:participants),
            converted: variants.sum(&:converted)
          }
        } }
      end

      def storage_key
        experiment_name
      end
    end

    attr_reader :participant
    delegate :configuration, :experiment_name, :variants, :control, :funnels,
      :storage_key, :started?, :started_at, :start!, :resettable?, :winner?,
      :winner, :allow_multiple_conversions?, :allow_multiple_goals?, :callbacks,
      to: :class

    def initialize(participant)
      @participant = participant
    end

    def algorithm
      @algorithm ||= self.class.algorithm.new(self)
    end

    def choose!(override: nil, metadata: nil, **opts)
      return control if TrailGuide.configuration.disabled

      variant = choose_variant!(override: override, metadata: metadata, **opts)
      participant.participating!(variant) unless override.present? && !configuration.store_override
      run_callbacks(:on_use, variant, metadata)
      variant
    end

    def choose_variant!(override: nil, excluded: false, metadata: nil)
      return control if TrailGuide.configuration.disabled
      if override.present?
        variant = variants.find { |var| var == override }
        return variant unless configuration.track_override && started?
      else
        return winner if winner?
        return control if excluded
        return control if !started? && configuration.start_manually
        start! unless started?
        return variants.find { |var| var == participant[storage_key] } if participating?
        return control unless TrailGuide.configuration.allow_multiple_experiments == true || !participant.participating_in_active_experiments?(TrailGuide.configuration.allow_multiple_experiments == false) 

        variant = algorithm.choose!(metadata: metadata)
      end

      variant.increment_participation!
      run_callbacks(:on_choose, variant, metadata)
      variant
    end

    def convert!(checkpoint=nil, metadata: nil)
      return false unless participating?
      raise InvalidGoalError, "Invalid goal checkpoint `#{checkpoint}` for `#{experiment_name}`." unless checkpoint.present? || funnels.empty?
      raise InvalidGoalError, "Invalid goal checkpoint `#{checkpoint}` for `#{experiment_name}`." unless checkpoint.nil? || funnels.any? { |funnel| funnel == checkpoint.to_s.underscore.to_sym }
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
      run_callbacks(:on_convert, variant, checkpoint, metadata)
      variant
    end

    def participating?
      participant.participating?(self)
    end

    def converted?(checkpoint=nil)
      participant.converted?(self, checkpoint)
    end

    def run_callbacks(hook, *args)
      return unless callbacks[hook]
      args.unshift(self)
      callbacks[hook].each do |callback|
        if callback.respond_to?(:call)
          callback.call(*args)
        else
          send(callback, *args)
        end
      end
    end
  end
end
