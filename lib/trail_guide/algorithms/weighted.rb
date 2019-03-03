module TrailGuide
  module Algorithms
    class Weighted
      attr_reader :experiment

      def self.choose!(experiment)
        new(experiment).choose!
      end

      def initialize(experiment)
        @experiment = experiment
      end

      def choose!
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
