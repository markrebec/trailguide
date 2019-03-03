module TrailGuide
  module Helper
    def trailguide(metric=nil, **opts, &block)
      @trailguide_proxy ||= HelperProxy.new(self)
      if metric.nil?
        @trailguide_proxy
      else
        @trailguide_proxy.choose!(metric, **opts, &block)
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

      def convert!(metric, checkpoint=nil, &block)
        new(metric).convert!(checkpoint, &block)
      end

      def participant
        # TODO rework participant adapters to accept a user instead of a context
        @participant ||= begin
          if context.respond_to?(:trailguide_participant, true)
            TrailGuide::Participant.new(Struct.new(:current_user).new(context.send(:trailguide_participant)))
          elsif context.respond_to?(:current_user, true)
            TrailGuide::Participant.new(context)
          else
            # TODO temporary while devloping/testing
            TrailGuide::Participant.new(Struct.new(:current_user).new(Struct.new(:id).new(rand(1...9999))))
          end
        end
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
        variant = experiment.choose!(**opts) # TODO override: variant
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
          template ||= "#{prefix.to_s}#{metric_descriptor.to_s.underscore}/#{variant.name.to_s.underscore}"

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
    end
  end
end
