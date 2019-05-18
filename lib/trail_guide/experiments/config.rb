module TrailGuide
  module Experiments
    class Config < Canfig::Config
      DEFAULT_KEYS = [
        :name, :summary, :preview_url, :algorithm, :groups, :variants, :goals,
        :start_manually, :reset_manually, :store_override, :track_override,
        :combined, :allow_multiple_conversions, :allow_multiple_goals,
        :track_winner_conversions, :skip_request_filter, :target_sample_size,
        :can_resume, :enable_calibration
      ].freeze

      CALLBACK_KEYS = [
        :on_start, :on_schedule, :on_stop, :on_pause, :on_resume, :on_winner,
        :on_reset, :on_delete, :on_choose, :on_use, :on_convert,
        :on_redis_failover, :allow_participation, :allow_conversion,
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
          opts[:name] = nil
          opts[:goals] = ancestor.goals.dup
          opts[:combined] = ancestor.combined.dup
          opts[:variants] = ancestor.variants.map { |var| var.dup(experiment) }
          opts = opts.merge(ancestor.callbacks.map { |k,v| [k,[v].flatten.compact] }.to_h)
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

      def can_resume?
        !!can_resume
      end

      def enable_calibration?
        !!enable_calibration
      end

      def name
        @name ||= (self[:name] || experiment.name).try(:to_s).try(:underscore).try(:to_sym)
      end

      def groups(*grps)
        self[:groups] ||= []
        unless grps.empty?
          self[:groups] = self[:groups].concat([grps].flatten.map { |g| g.to_s.underscore.to_sym })
        end
        self[:groups]
      end

      def groups=(*grps)
        self[:groups] = [grps].flatten.map { |g| g.to_s.underscore.to_sym }
      end

      def group(grp=nil)
        unless grp.nil?
          groups << grp.to_s.underscore.to_sym
          return groups.last
        end
        groups.first
      end

      def group=(grp)
        groups.unshift(grp.to_s.underscore.to_sym)
        groups.first
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
        goals << Metrics::Goal.new(experiment, name)
      end
      alias_method :funnel, :goal

      def goals=(*names)
        self[:goals] = [names].flatten.map { |g| Metrics::Goal.new(experiment, g) }
      end

      def goals(*names)
        self[:goals] ||= []
        unless names.empty?
          self[:goals] = self[:goals].concat([names].flatten.map { |g| Metrics::Goal.new(experiment, g) })
        end
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

      def on_schedule(meth=nil, &block)
        self[:on_schedule] ||= []
        self[:on_schedule] << (meth || block)
      end

      def on_stop(meth=nil, &block)
        self[:on_stop] ||= []
        self[:on_stop] << (meth || block)
      end

      def on_pause(meth=nil, &block)
        self[:on_pause] ||= []
        self[:on_pause] << (meth || block)
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

      def allow_participation(meth=nil, &block)
        self[:allow_participation] ||= []
        self[:allow_participation] << (meth || block)
      end

      def allow_conversion(meth=nil, &block)
        self[:allow_conversion] ||= []
        self[:allow_conversion] << (meth || block)
      end

      def rollout_winner(meth=nil, &block)
        self[:rollout_winner] ||= []
        self[:rollout_winner] << (meth || block)
      end
    end
  end
end
