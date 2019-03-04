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

      def config_algorithm
        config_algo = TrailGuide.configuration.algorithm
        case config_algo
        when :weighted
          config_algo = TrailGuide::Algorithms::Weighted
        when :bandit
          config_algo = TrailGuide::Algorithms::Bandit
        when :distributed
          config_algo = TrailGuide::Algorithms::Distributed
        when :random
          config_algo = TrailGuide::Algorithms::Random
        else
          config_algo = config_algo.constantize if config_algo.is_a?(String)
        end
        config_algo
      end

      def algorithm(algo=nil)
        @algorithm = TrailGuide::Algorithms.algorithm(algo) unless algo.nil?
        @algorithm ||= TrailGuide::Algorithms.algorithm(TrailGuide.configuration.algorithm)
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

      def callbacks
        @callbacks ||= begin
          callbacks = {
            on_choose:   [TrailGuide.configuration.on_experiment_choose].compact,
            on_convert:  [TrailGuide.configuration.on_experiment_convert].compact,
            on_start:    [TrailGuide.configuration.on_experiment_start].compact,
            on_stop:     [TrailGuide.configuration.on_experiment_stop].compact,
            on_reset:    [TrailGuide.configuration.on_experiment_reset].compact,
            on_delete:   [TrailGuide.configuration.on_experiment_delete].compact,
          }
        end
      end

      def on_choose(meth=nil, &block)
        callbacks[:on_choose] << (meth || block)
      end

      def on_convert(meth=nil, &block)
        callbacks[:on_convert] << (meth || block)
      end

      def on_start(meth=nil, &block)
        callbacks[:on_start] << (meth || block)
      end

      def on_stop(meth=nil, &block)
        callbacks[:on_stop] << (meth || block)
      end

      def on_reset(meth=nil, &block)
        callbacks[:on_reset] << (meth || block)
      end

      def on_delete(meth=nil, &block)
        callbacks[:on_delete] << (meth || block)
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
      :allow_multiple_conversions?, :allow_multiple_goals?, :callbacks,
      to: :class

    def initialize(participant)
      @participant = participant
    end

    def algorithm
      @algorithm ||= self.class.algorithm.new(self)
    end

    def choose!(override: nil, excluded: false)
      return control if TrailGuide.configuration.disabled
      if override.present?
        variant = variants.find { |var| var == override }
        return variant unless TrailGuide.configuration.store_override && started?
      else
        return winner if winner?
        return control if excluded
        return control if !started? && TrailGuide.configuration.start_manually
        start! unless started?
        return variants.find { |var| var == participant[storage_key] } if participating?
        return control unless TrailGuide.configuration.allow_multiple_experiments == true || !participant.participating_in_active_experiments?(TrailGuide.configuration.allow_multiple_experiments == false) 

        variant = algorithm.choose!
      end

      participant.participating!(variant)
      variant.increment_participation!
      run_callbacks(:on_choose, variant)
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
      run_callbacks(:on_convert, variant, checkpoint)
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
