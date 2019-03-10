module TrailGuide
  module Experiments
    class Config < Canfig::Config
      DEFAULT_KEYS = [
        :name, :summary, :preview_url, :algorithm, :metric, :variants, :goals,
        :start_manually, :reset_manually, :store_override, :track_override,
        :combined, :allow_multiple_conversions, :allow_multiple_goals,
        :track_winner_conversions, :skip_request_filter
      ].freeze

      CALLBACK_KEYS = [
        :on_start, :on_stop, :on_resume, :on_winner, :on_reset, :on_delete,
        :on_choose, :on_use, :on_convert,
        :on_redis_failover,
        :rollout_winner
      ].freeze

      def default_config
        DEFAULT_KEYS.map do |key|
          [key, nil]
        end.to_h.merge({
          variants: [],
          goals: [],
          combined: []
        }).merge(callback_config)
      end

      def callback_config
        CALLBACK_KEYS.map do |key|
          [key, []]
        end.to_h
      end

      attr_reader :experiment

      def initialize(experiment, *args, **opts, &block)
        @experiment = experiment
        opts = opts.merge(default_config)
        ancestor = opts.delete(:inherit)
        if ancestor.present?
          keys = opts.keys.dup.concat(args).concat(DEFAULT_KEYS).concat(CALLBACK_KEYS).uniq
          opts = opts.merge(ancestor.to_h.slice(*keys))
          opts = opts.merge(ancestor.callbacks.map { |k,v| [k,[v].flatten.compact] }.to_h)
          opts[:name] = nil
          opts[:variants] = ancestor.variants.map { |var| var.dup(experiment) }
          opts[:goals] = ancestor.goals.dup
          opts[:combined] = ancestor.combined.dup
        end
        super(*args, **opts, &block)
      end

      def start_manually?
        !!start_manually
      end

      def reset_manually?
        !!reset_manually
      end

      def allow_multiple_conversions?
        !!allow_multiple_conversions
      end

      def allow_multiple_goals?
        !!allow_multiple_goals
      end

      def track_winner_conversions?
        !!track_winner_conversions
      end

      def skip_request_filter?
        !!skip_request_filter
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
        to_h.slice(*CALLBACK_KEYS).map { |k,v| [k, [v].flatten.compact] }.to_h
      end

      def on_choose(meth=nil, &block)
        self[:on_choose] ||= []
        self[:on_choose] << (meth || block)
      end

      def on_use(meth=nil, &block)
        self[:on_use] ||= []
        self[:on_use] << (meth || block)
      end

      def on_convert(meth=nil, &block)
        self[:on_convert] ||= []
        self[:on_convert] << (meth || block)
      end

      def on_start(meth=nil, &block)
        self[:on_start] ||= []
        self[:on_start] << (meth || block)
      end

      def on_stop(meth=nil, &block)
        self[:on_stop] ||= []
        self[:on_stop] << (meth || block)
      end

      def on_resume(meth=nil, &block)
        self[:on_resume] ||= []
        self[:on_resume] << (meth || block)
      end

      def on_winner(meth=nil, &block)
        self[:on_winner] ||= []
        self[:on_winner] << (meth || block)
      end

      def on_reset(meth=nil, &block)
        self[:on_reset] ||= []
        self[:on_reset] << (meth || block)
      end

      def on_delete(meth=nil, &block)
        self[:on_delete] ||= []
        self[:on_delete] << (meth || block)
      end

      def on_redis_failover(meth=nil, &block)
        self[:on_redis_failover] ||= []
        self[:on_redis_failover] << (meth || block)
      end

      def rollout_winner(meth=nil, &block)
        self[:rollout_winner] ||= []
        self[:rollout_winner] << (meth || block)
      end
    end
  end
end
