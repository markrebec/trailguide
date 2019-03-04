module TrailGuide
  module Helper
    def trailguide(metric=nil, **opts, &block)
      proxy = HelperProxy.new(self)
      return proxy if metric.nil?
      proxy.choose!(metric, **opts, &block)
    end

    class HelperProxy
      attr_reader :context

      def initialize(context, participant: nil)
        @context = context
        @participant = participant
      end

      def new(metric)
        MetricProxy.new(context, metric, participant: participant)
      end

      def choose!(metric, **opts, &block)
        new(metric).choose!(**opts, &block)
      end

      def run!(metric, **opts)
        new(metric).run!(**opts)
      end

      def render!(metric, **opts)
        new(metric).render!(**opts)
      end

      def convert!(metric, checkpoint=nil, &block)
        new(metric).convert!(checkpoint, &block)
      end

      def participant
        @participant ||= TrailGuide::Participant.new(context)
      end

      def context_type
        if context.is_a?(ActionView::Context)
          :template
        elsif context.is_a?(ActionController::Base)
          :controller
        end
      end
    end

    class MetricProxy < HelperProxy
      attr_reader :metric

      def initialize(context, metric, **opts)
        super(context, **opts)
        @metric = metric
      end

      def choose!(**opts, &block)
        raise ArgumentError, "Please provide a single experiment" unless experiments.length == 1
        opts = {override: override_variant, excluded: exclude_visitor?}.merge(opts)
        variant = experiment.choose!(**opts)
        if block_given?
          yield variant
        else
          variant
        end
      end

      def run!(methods: nil, **opts)
        raise ArgumentError, "Please provide a single experiment" unless experiments.length == 1
        choose!(**opts) do |variant|
          varmeth = methods[variant.name] if methods
          varmeth ||= variant.name

          unless context.respond_to?(varmeth, true)
            if context_type == :controller
              raise NoMethodError,
                "You must define a controller method that matches variant `#{variant.name}` in your experiment `#{metric}`. In this case it looks like you need to define #{context.class.name}##{varmeth}(metadata={})"
            elsif context_type == :template
              raise NoMethodError,
                "You must define a helper method that matches variant `#{variant.name}` in your experiment `#{metric}`. In this case it looks like you need to define ApplicationHelper##{varmeth}(metadata={})"
            else
              raise NoMethodError,
                "You must define a method that matches variant `#{variant.name}` in your experiment `#{metric}`. In this case it looks like you need to define #{context.class.name}##{varmeth}(metadata={})"
            end
          end

          arguments = context.method(varmeth).parameters
          if arguments.empty?
            context.send(varmeth)
          elsif arguments.length > 1 || arguments[0][0] == :rest
            context.send(varmeth, variant, **variant.metadata)
          elsif arguments.length == 1
            context.send(varmeth, **variant.metadata)
          end
        end
      end

      def render!(prefix: nil, templates: nil, **opts)
        raise NoMethodError, "The current context does not support rendering. Rendering is only available for controllers and views." unless context.respond_to?(:render, true)
        raise ArgumentError, "Please provide a single experiment" unless experiments.length == 1
        choose!(**opts) do |variant|
          locals = { variant: variant, metadata: variant.metadata }
          locals = { locals: locals } if context_type == :controller

          template = templates[variant.name] if templates
          prefix ||= (context.try(:view_context) || context).lookup_context.prefixes.first + '/'
          template ||= "#{prefix.to_s}#{variant.experiment.experiment_name.to_s.underscore}/#{variant.name.to_s.underscore}"

          context.send(:render, template.to_s, **locals)
        end
      end

      def convert!(checkpoint=nil, &block)
        checkpoints = experiments.map { |experiment| experiment.convert!(checkpoint) }
        return false unless checkpoints.any?
        if block_given?
          yield checkpoints
        else
          checkpoints
        end
      end

      def experiments
        @experiments ||= TrailGuide::Catalog.select(metric).map do |experiment|
          experiment.new(participant)
        end
      end

      def experiment
        @experiment ||= experiments.first
      end

      def override_variant
        return unless context.respond_to?(:params, true)
        params = context.send(:params)
        return unless params.key?(TrailGuide.configuration.override_parameter)
        experiment_params = params[TrailGuide.configuration.override_parameter]
        return unless experiment_params.key?(experiment.experiment_name.to_s)
        varname = experiment_params[experiment.experiment_name.to_s]
        variant = experiment.variants.find { |var| var == varname }
        variant.try(:name)
      end

      def exclude_visitor?
        instance_exec(context, &TrailGuide.configuration.request_filter)
      end

      def is_preview?
        return false unless context.respond_to?(:request, true)
        headers = context.send(:request).try(:headers)
        headers && headers['x-purpose'] == 'preview'
      end

      def is_filtered_user_agent?
        return false if TrailGuide.configuration.filtered_user_agents.empty?
        return false unless context.respond_to?(:request, true)
        request = context.send(:request)
        return false unless request && request.user_agent

        TrailGuide.configuration.filtered_user_agents do |ua|
          return true if ua.class == String && request.user_agent == ua
          return true if ua.class == Regexp && request.user_agent =~ ua
        end

        return false
      end

      def is_filtered_ip_address?
        return false if TrailGuide.configuration.filtered_ip_addresses.empty?
        return false unless context.respond_to?(:request, true)
        request = context.send(:request)
        return false unless request && request.ip

        TrailGuide.configuration.filtered_ip_addresses.each do |ip|
          return true if ip.class == String && request.ip == ip
          return true if ip.class == Regexp && request.ip =~ ip
          return true if ip.class == Range && ip.first.class == IPAddr && ip.include?(IPAddr.new(request.ip))
        end

        return false
      end
    end
  end
end
