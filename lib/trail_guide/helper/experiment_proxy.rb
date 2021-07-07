module TrailGuide
  module Helper
    class ExperimentProxy < HelperProxy
      attr_reader :key

      def initialize(context, key, **opts)
        super(context, **opts)
        @key = key.to_s.underscore.to_sym
      end

      def choose!(**opts, &block)
        raise NoExperimentsError, key if experiments.empty?
        raise TooManyExperimentsError, "Selecting a variant requires a single experiment, but `#{key}` matches more than one experiment." if experiments.length > 1
        raise TooManyExperimentsError, "Selecting a variant requires a single experiment, but `#{key}` refers to a combined experiment." if experiment.combined?
        opts = {override: override_variant, excluded: exclude_visitor?}.merge(opts)
        variant = experiment.choose!(**opts)
        if block_given?
          yield variant, opts[:metadata]
        else
          variant
        end
      end
      alias_method :enroll!, :choose!

      def choose(**opts, &block)
        choose!(**opts, &block)
      rescue NoExperimentsError => e
        raise e
      rescue => e
        TrailGuide.logger.error e
        experiment.control
      end
      alias_method :enroll, :choose

      def run!(methods: nil, **opts)
        choose!(**opts) do |variant, metadata|
          varmeth = methods[variant.name] if methods
          varmeth ||= variant.name

          unless context.respond_to?(varmeth, true)
            if context_type == :controller
              raise NoVariantMethodError,
                "Undefined local method `#{varmeth}`. You must define a controller method matching the variant `#{variant.name}` in your experiment `#{key}`. In this case it looks like you need to define #{context.class.name}##{varmeth}(metadata={})"
            elsif context_type == :template
              raise NoVariantMethodError,
                "Undefined local method `#{varmeth}`. You must define a helper method matching the variant `#{variant.name}` in your experiment `#{key}`. In this case it looks like you need to define ApplicationHelper##{varmeth}(metadata={})"
            else
              raise NoVariantMethodError,
                "Undefined local method `#{varmeth}`. You must define a method matching the variant `#{variant.name}` in your experiment `#{key}`. In this case it looks like you need to define #{context.class.name}##{varmeth}(metadata={})"
            end
          end

          arguments = context.method(varmeth).parameters
          if arguments.empty?
            context.send(varmeth)
          elsif arguments.length > 1 || arguments[0][0] == :rest
            if arguments.last[0] == :keyrest
              context.send(varmeth, variant, **variant.metadata)
            else
              context.send(varmeth, variant, variant.metadata)
            end
          elsif arguments.length == 1
            if arguments[0][0] == :keyrest
              context.send(varmeth, **variant.metadata)
            else
              context.send(varmeth, variant.metadata)
            end
          end
        end
      end

      def run(methods: nil, **opts)
        run!(methods: methods, **opts)
      rescue NoExperimentsError => e
        raise e
      rescue => e
        TrailGuide.logger.error e
        false
      end

      def render!(prefix: nil, templates: nil, locals: {}, **opts)
        raise UnsupportedContextError, "The current context (#{context}) does not support rendering. Rendering is only available in controllers and views." unless context.respond_to?(:render, true)
        choose!(**opts) do |variant, metadata|
          locals = { variant: variant, metadata: variant.metadata }.merge(locals)
          locals = { locals: locals } if context_type == :controller

          template = templates[variant.name] if templates
          prefix ||= (context.try(:view_context) || context).lookup_context.prefixes.first + '/' rescue ''
          template ||= "#{prefix.to_s}#{variant.experiment.experiment_name.to_s.underscore}/#{variant.name.to_s.underscore}"

          context.send(:render, template.to_s, **locals)
        end
      end

      def render(prefix: nil, templates: nil, locals: {}, **opts)
        render!(prefix: prefix, templates: templates, locals: locals, **opts)
      rescue NoExperimentsError => e
        raise e
      rescue => e
        TrailGuide.logger.error e
        false
      end

      def convert!(checkpoint=nil, **opts, &block)
        raise NoExperimentsError, key if experiments.empty?
        checkpoints = experiments.map do |experiment|
          ckpt = checkpoint || experiment.goals.find { |g| g == key }
          if experiment.combined?
            experiment.combined_experiments.map do |combo|
              combo.convert!(ckpt, **opts)
            end
          else
            experiment.convert!(ckpt, **opts)
          end
        end.flatten

        return false unless checkpoints.any?

        if block_given?
          yield checkpoints, opts[:metadata]
        else
          checkpoints
        end
      rescue NoExperimentsError => e
        unless TrailGuide.configuration.ignore_orphaned_groups?
          trace = e.backtrace.find { |t| !t.match?(Regexp.new(File.dirname(__FILE__))) }
            .to_s.split(Rails.root.to_s).last
            .split(':').first(2).join(':')
          TrailGuide.catalog.orphaned(key, trace)
        end
        false
      end

      def convert(checkpoint=nil, **opts, &block)
        convert!(checkpoint, **opts, &block)
      rescue => e
        TrailGuide.logger.error e
        false
      end

      def experiments
        @experiments ||= TrailGuide.catalog.select(key).map do |experiment|
          experiment.new(participant)
        end
      end

      def experiment
        @experiment ||= experiments.first
      end

      def override_variant
        return unless context.respond_to?(:trailguide_params, true) || context.respond_to?(:params, true)
        params = context.try(:trailguide_params) || context.try(:params)
        return unless params.key?(TrailGuide.configuration.override_parameter)
        experiment_params = params[TrailGuide.configuration.override_parameter]
        return unless experiment_params.key?(experiment.experiment_name.to_s)
        varname = experiment_params[experiment.experiment_name.to_s]
        variant = experiment.variants.find { |var| var == varname }
        variant.try(:name)
      end

      def exclude_visitor?
        return false if experiment.configuration.skip_request_filter?
        context.send(:trailguide_excluded_request?)
      end
    end
  end
end
