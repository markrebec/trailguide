module TrailGuide
  module Helper
    def trailguide(metric=nil, **opts, &block)
      if metric.nil?
        HelperProxy.new(self)
      else
        MetricProxy.new(self, metric).choose!(**opts, &block)
      end
    end

    class HelperProxy
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def new(metric)
        MetricProxy.new(context, metric)
      end

      def choose!(metric, **opts, &block)
        new(metric).choose!(**opts, &block)
      end

      def run!(metric)
        new(metric).run!
      end

      def render!(metric)
        new(metric).render!
      end

      def convert!(metric, checkpoint=nil, &block)
        new(metric).convert!(checkpoint, &block)
      end
    end

    class MetricProxy
      attr_reader :context, :metric

      def initialize(context, metric)
        @context = context
        @metric = metric
      end

      # requires a single experiment
      def choose!(**opts, &block)
        variant = experiment.choose!(**opts) # TODO override: variant
        if block_given?
          yield variant
        else
          variant
        end
      end

      # requires a single experiment
      def run!
        choose! do |variant|
          puts "RUN METHODS"
          # TODO run methods
        end
      end

      # requires a single experiment
      def render!
        choose! do |variant|
          puts "RENDER TEMPLATES"
          # TODO render templates
        end
      end

      # can use a metric for multiple experiments
      def convert!(checkpoint=nil, &block)
        checkpoints = experiments.map { |experiment| experiment.convert!(checkpoint) }
        return unless checkpoints.any?
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
    end
  end
end
