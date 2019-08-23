module TrailGuide
  module Helper
    class HelperProxy
      attr_reader :context

      def initialize(context, participant: nil)
        @context = context
        @participant = participant
      end

      def new(key)
        ExperimentProxy.new(context, key, participant: participant)
      end

      def choose!(key, **opts, &block)
        new(key).choose!(**opts, &block)
      end
      alias_method :enroll!, :choose!

      def choose(key, **opts, &block)
        new(key).choose(**opts, &block)
      end
      alias_method :enroll, :choose

      def run!(key, **opts)
        new(key).run!(**opts)
      end

      def run(key, **opts)
        new(key).run(**opts)
      end

      def render!(key, **opts)
        new(key).render!(**opts)
      end

      def render(key, **opts)
        new(key).render(**opts)
      end

      def convert!(key, checkpoint=nil, **opts, &block)
        new(key).convert!(checkpoint, **opts, &block)
      end

      def convert(key, checkpoint=nil, **opts, &block)
        new(key).convert(checkpoint, **opts, &block)
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
  end
end
