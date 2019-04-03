require "trail_guide/experiments/base"
require "trail_guide/experiments/combined_config"

module TrailGuide
  class CombinedExperiment < Experiments::Base
    class << self
      delegate :parent, to: :configuration

      def configuration
        @configuration ||= Experiments::CombinedConfig.new(self)
      end

      # TODO if just I delegate on this inheriting class, will that override the 
      # defined methods on the base class? and will they interplay nicely? like
      # with `started?` calling `started_at`, etc.?
      #
      # really wishing i'd written some specs right about now :-P
      def start!
        parent.start!
      end

      def stop!
        parent.stop!
      end

      def resume!
        parent.resume!
      end

      def started_at
        parent.started_at
      end

      def stopped_at
        parent.stopped_at
      end
    end

    delegate :parent, to: :class
    delegate :running?, :started?, :started_at, :start!, to: :parent

    # use the parent experiment as the algorithm and map to the matching variant
    def algorithm_choose!(metadata: nil)
      variant = parent.new(participant.participant).choose!(metadata: metadata)
      variants.find { |var| var == variant.name }
    end
  end
end
