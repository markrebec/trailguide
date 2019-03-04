module TrailGuide
  module Algorithms
    class Random
      attr_reader :experiment

      def self.choose!(experiment)
        new(experiment).choose!
      end

      def initialize(experiment)
        @experiment = experiment
      end

      def choose!
        experiment.variants.sample
      end
    end
  end
end
