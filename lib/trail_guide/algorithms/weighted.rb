module TrailGuide
  module Algorithms
    class Weighted
      attr_reader :experiment

      def self.choose!(experiment, **opts)
        new(experiment).choose!(**opts)
      end

      def initialize(experiment)
        @experiment = experiment
      end

      def choose!(**opts)
        weights   = experiment.variants.map(&:weight)
        reference = rand * weights.inject(:+)

        experiment.variants.zip(weights).each do |variant,weight|
          return variant if weight >= reference
          reference -= weight
        end
      end
    end
  end
end
