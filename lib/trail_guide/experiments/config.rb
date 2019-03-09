module TrailGuide
  module Experiments
    class Config < Canfig::Config
      ENGINE_CONFIG_KEYS = [
        :start_manually, :reset_manually, :store_override, :track_override,
        :algorithm, :allow_multiple_conversions, :allow_multiple_goals,
        :track_winner_conversions
      ].freeze

      CALLBACK_KEYS = [
        :on_start, :on_stop, :on_resume, :on_winner, :on_reset, :on_delete,
        :on_choose, :on_use, :on_convert,
        :on_redis_failover,
        :rollout
      ].freeze

      def self.engine_config
        ENGINE_CONFIG_KEYS.map do |key|
          [key, TrailGuide.configuration.send(key.to_sym)]
        end.to_h
      end

      def self.default_config
        { name: nil,
          metric: nil,
          variants: [],
          goals: [],
          combined: [],
          summary: nil,
          preview_url: nil,
        }
      end

      def self.callbacks_config
        {
          on_choose:          [TrailGuide.configuration.on_experiment_choose].flatten.compact,
          on_use:             [TrailGuide.configuration.on_experiment_use].flatten.compact,
          on_convert:         [TrailGuide.configuration.on_experiment_convert].flatten.compact,
          on_start:           [TrailGuide.configuration.on_experiment_start].flatten.compact,
          on_stop:            [TrailGuide.configuration.on_experiment_stop].flatten.compact,
          on_resume:          [TrailGuide.configuration.on_experiment_resume].flatten.compact,
          on_winner:          [TrailGuide.configuration.on_experiment_winner].flatten.compact,
          on_reset:           [TrailGuide.configuration.on_experiment_reset].flatten.compact,
          on_delete:          [TrailGuide.configuration.on_experiment_delete].flatten.compact,
          on_redis_failover:  [TrailGuide.configuration.on_redis_failover].flatten.compact,
          rollout:            [TrailGuide.configuration.return_experiment_winner].flatten.compact,
        }
      end

      attr_reader :experiment

      def initialize(experiment, *args, **opts, &block)
        @experiment = experiment
        ancestor = opts.delete(:inherit)
        if ancestor.present?
          opts = opts.merge(ancestor.to_h)
          opts[:name] = nil
          opts[:variants] = ancestor.variants.map { |var| var.dup(experiment) }
          opts = opts.merge(ancestor.callbacks.map { |k,v| [k,v.dup] }.to_h)
        else
          opts = opts.merge(self.class.engine_config)
          opts = opts.merge(self.class.default_config)
          opts = opts.merge(self.class.callbacks_config)
        end
        super(*args, **opts, &block)
      end

      def resettable?
        !reset_manually
      end

      def allow_multiple_conversions?
        allow_multiple_conversions
      end

      def allow_multiple_goals?
        allow_multiple_goals
      end

      def track_winner_conversions?
        track_winner_conversions
      end

      def name
        @name ||= (self[:name] || experiment.name).try(:to_s).try(:underscore).try(:to_sym)
      end

      def metric
        @metric ||= (self[:metric] || name).try(:to_s).try(:underscore).try(:to_sym)
      end

      def algorithm
        @algorithm ||= TrailGuide::Algorithms.algorithm(self[:algorithm])
      end

      def variant(varname, metadata: {}, weight: 1, control: false)
        raise ArgumentError, "The variant `#{varname}` already exists in the experiment `#{name}`" if variants.any? { |var| var == varname }
        control = true if variants.empty?
        variants.each(&:variant!) if control
        variant = Variant.new(experiment, varname, metadata: metadata, weight: weight, control: control)
        variants << variant
        variant
      end

      def control
        return variants.find { |var| var.control? } || variants.first
      end

      def control=(name)
        variants.each(&:variant!)
        var_idx = variants.index { |var| var == name }

        if var_idx.nil?
          variant = Variant.new(experiment, name, control: true)
          variants.push(variant)
        else
          variant = variants[var_idx]
          variant.control!
        end

        variant
      end

      def goal(name)
        goals << name.to_s.underscore.to_sym
      end
      alias_method :funnel, :goal

      def goals
        self[:goals]
      end
      alias_method :funnels, :goals

      def combined?
        !combined.empty?
      end

      def preview_url?
        !!preview_url
      end

      def callbacks
        to_h.slice(*CALLBACK_KEYS)
      end

      def on_choose(meth=nil, &block)
        self[:on_choose] << (meth || block)
      end

      def on_use(meth=nil, &block)
        self[:on_use] << (meth || block)
      end

      def on_convert(meth=nil, &block)
        self[:on_convert] << (meth || block)
      end

      def on_start(meth=nil, &block)
        self[:on_start] << (meth || block)
      end

      def on_stop(meth=nil, &block)
        self[:on_stop] << (meth || block)
      end

      def on_resume(meth=nil, &block)
        self[:on_resume] << (meth || block)
      end

      def on_winner(meth=nil, &block)
        self[:on_winner] << (meth || block)
      end

      def on_reset(meth=nil, &block)
        self[:on_reset] << (meth || block)
      end

      def on_delete(meth=nil, &block)
        self[:on_delete] << (meth || block)
      end

      def on_redis_failover(meth=nil, &block)
        self[:on_redis_failover] << (meth || block)
      end

      def rollout(meth=nil, &block)
        self[:rollout] << (meth || block)
      end
    end
  end
end
