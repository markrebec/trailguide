module TrailGuide
  module Helper
    def trailguide(metric=nil, **opts, &block)
      @trailguide_proxy ||= HelperProxy.new(self)
      @trailguide_proxy = HelperProxy.new(self) if @trailguide_proxy.context != self
      return @trailguide_proxy if metric.nil?
      @trailguide_proxy.choose!(metric, **opts, &block)
    end

    def trailguide_participant
      @trailguide_participant ||= TrailGuide::Participant.new(self)
      @trailguide_participant = TrailGuide::Participant.new(self) if @trailguide_participant.context != self
      @trailguide_participant
    end

    def trailguide_excluded_request?
      @trailguide_excluded_request ||= instance_exec(self, &TrailGuide.configuration.request_filter)
    end

    def is_preview?
      return false unless respond_to?(:request, true)
      headers = request.try(:headers)
      headers && headers['x-purpose'] == 'preview'
    end

    def is_filtered_user_agent?
      return @is_filtered_user_agent unless @is_filtered_user_agent.nil?

      @is_filtered_user_agent = begin
        @user_agent_filter_proc ||= -> {
          return false if TrailGuide.configuration.filtered_user_agents.nil? || TrailGuide.configuration.filtered_user_agents.empty?
          return false unless respond_to?(:request, true) && request.user_agent

          TrailGuide.configuration.filtered_user_agents.each do |ua|
            return true if ua.class == String && request.user_agent == ua
            return true if ua.class == Regexp && request.user_agent =~ ua
          end

          return false
        }
        instance_exec(&@user_agent_filter_proc)
      end
    end

    def is_filtered_ip_address?
      return @is_filtered_ip_address unless @is_filtered_ip_address.nil?

      @is_filtered_ip_address = begin
        @ip_address_filter_proc ||= -> {
          return false if TrailGuide.configuration.filtered_ip_addresses.nil? || TrailGuide.configuration.filtered_ip_addresses.empty?
          return false unless respond_to?(:request, true) && request.ip

          TrailGuide.configuration.filtered_ip_addresses.each do |ip|
            return true if ip.class == String && request.ip == ip
            return true if ip.class == Regexp && request.ip =~ ip
            return true if ip.class == Range && ip.first.class == IPAddr && ip.include?(IPAddr.new(request.ip))
          end

          return false
        }
        instance_exec(&@ip_address_filter_proc)
      end
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

      def convert!(metric, checkpoint=nil, **opts, &block)
        new(metric).convert!(checkpoint, **opts, &block)
      end

      def participant
        @participant ||= context.send(:trailguide_participant)
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
        raise NoExperimentsError, "Could not find any experiments matching `#{metric}`." if experiments.empty?
      end

      def choose!(**opts, &block)
        raise TooManyExperimentsError, "Selecting a variant requires a single experiment, but the metric `#{metric}` matches more than one experiment." if experiments.length > 1
        opts = {override: override_variant, excluded: exclude_visitor?}.merge(opts)
        variant = experiment.choose!(**opts)
        if block_given?
          yield variant, opts[:metadata]
        else
          variant
        end
      end

      def run!(methods: nil, **opts)
        choose!(**opts) do |variant, metadata|
          varmeth = methods[variant.name] if methods
          varmeth ||= variant.name

          unless context.respond_to?(varmeth, true)
            if context_type == :controller
              raise NoVariantMethodError,
                "Undefined local method `#{varmeth}`. You must define a controller method matching the variant `#{variant.name}` in your experiment `#{metric}`. In this case it looks like you need to define #{context.class.name}##{varmeth}(metadata={})"
            elsif context_type == :template
              raise NoVariantMethodError,
                "Undefined local method `#{varmeth}`. You must define a helper method matching the variant `#{variant.name}` in your experiment `#{metric}`. In this case it looks like you need to define ApplicationHelper##{varmeth}(metadata={})"
            else
              raise NoVariantMethodError,
                "Undefined local method `#{varmeth}`. You must define a method matching the variant `#{variant.name}` in your experiment `#{metric}`. In this case it looks like you need to define #{context.class.name}##{varmeth}(metadata={})"
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

      def render!(prefix: nil, templates: nil, locals: {}, **opts)
        raise UnsupportedContextError, "The current context (#{context}) does not support rendering. Rendering is only available in controllers and views." unless context.respond_to?(:render, true)
        choose!(**opts) do |variant, metadata|
          locals = { variant: variant, metadata: variant.metadata }.merge(locals)
          locals = { locals: locals } if context_type == :controller

          template = templates[variant.name] if templates
          prefix ||= (context.try(:view_context) || context).lookup_context.prefixes.first + '/'
          template ||= "#{prefix.to_s}#{variant.experiment.experiment_name.to_s.underscore}/#{variant.name.to_s.underscore}"

          context.send(:render, template.to_s, **locals)
        end
      end

      def convert!(checkpoint=nil, **opts, &block)
        checkpoints = experiments.map { |experiment| experiment.convert!(checkpoint, **opts) }
        return false unless checkpoints.any?
        if block_given?
          yield checkpoints, opts[:metadata]
        else
          checkpoints
        end
      end

      def experiments
        @experiments ||= TrailGuide.catalog.select(metric).map do |experiment|
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
        return false if experiment.configuration.skip_request_filter?
        context.send(:trailguide_excluded_request?)
      end
    end
  end
end
