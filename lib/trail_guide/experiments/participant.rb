module TrailGuide
  module Experiments
    class Participant
      attr_reader :experiment, :participant

      def initialize(experiment, participant)
        @experiment = experiment
        @participant = participant
      end

      def participating?
        @participating ||= variant.present?#participant.participating?(experiment)
      end

      def converted?(checkpoint=nil)
        @converted ||= participant.converted?(experiment, checkpoint)
      end

      def variant
        @variant ||= participant.variant(experiment)
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
