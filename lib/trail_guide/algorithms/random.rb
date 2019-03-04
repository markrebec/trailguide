module TrailGuide
  module Algorithms
    class Random
      attr_reader :experiment

      def self.choose!(experiment, **opts)
        new(experiment).choose!(**opts)
      end

      def initialize(experiment)
        @experiment = experiment
      end

      def choose!(**opts)
        experiment.variants.sample
      end
    end
  end
end
