module TrailGuide
  class Experiment
    # TODO maybe use a custon canfig object with specific keys and methods built-in? could also initialize with the top-level config defaults... and ensure it's created with a reference to self...
    extend Canfig::Instance

    class << self
      def inherited(child)
        # TODO allow inheriting algo, variants, goals, metrics, etc.
        TrailGuide::Catalog.register(child)
        child.configure do |config|
          [:start_manually, :reset_manually, :store_override, :track_override, :algorithm, :allow_multiple_conversions, :allow_multiple_goals].each do |key|
            config.send("#{key}=".to_sym, TrailGuide.configuration.send(key.to_sym))
          end
        end
      end

      def resettable?
        !configuration.reset_manually
      end

      def allow_multiple_conversions?
        configuration.allow_multiple_conversions
      end

      def allow_multiple_goals?
        configuration.allow_multiple_goals
      end

      def experiment_name
        # TODO can maybe be smarter about memoizing this in the config?
        @experiment_name ||= (configuration.name || name).try(:to_s).try(:underscore).try(:to_sym)
      end

      def metric
        @metric ||= (configuration.metric || experiment_name).try(:to_s).try(:underscore).try(:to_sym)
      end

      def algorithm
        @algorithm ||= TrailGuide::Algorithms.algorithm(configuration.algorithm)
      end

      def variant(name, metadata: {}, weight: 1, control: false)
        raise ArgumentError, "The variant `#{name}` already exists in the experiment `#{experiment_name}`" if variants.any? { |var| var == name }
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

      def callbacks
        @callbacks ||= begin
          callbacks = {
            on_choose:   [TrailGuide.configuration.on_experiment_choose].compact,
            on_use:      [TrailGuide.configuration.on_experiment_use].compact,
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

      def on_use(meth=nil, &block)
        callbacks[:on_use] << (meth || block)
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
