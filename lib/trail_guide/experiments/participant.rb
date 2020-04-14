module TrailGuide
  module Experiments
    class Participant
      attr_reader :experiment, :participant
      delegate :context, :subject, to: :participant

      def initialize(experiment, participant)
        @experiment = experiment
        @participant = participant
      end

      def participating?(include_control=true)
        participant.participating?(experiment, include_control)
      end

      def participating!(variant)
        @variant = variant
        participant.participating!(variant) if experiment.configuration.sticky_assignment?
      end

      def converted?(checkpoint=nil)
        @converted ||= {}
        converted_key = checkpoint || :converted
        @converted[converted_key] = participant.converted?(experiment, checkpoint) unless @converted.key?(converted_key)
        @converted[converted_key]
      end

      def converted!(variant, checkpoint=nil, reset: false)
        @converted ||= {}
        @converted[checkpoint || :converted] ||= true
        participant.converted!(variant, checkpoint, reset: reset)
      end

      def variant
        @variant ||= participant.variant(experiment)
      end

      def exit!
        @converted = nil
        @variant = nil
        participant.exit!(experiment)
      end

      def method_missing(meth, *args, &block)
        return participant.send(meth, *args, &block) if participant.respond_to?(meth, true)
        super
      end

      def respond_to_missing?(meth, include_private=false)
        participant.respond_to?(meth, include_private)
      end
    end
  end
end
