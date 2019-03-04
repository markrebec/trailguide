module TrailGuide
  module Algorithms
    class Distributed
      attr_reader :experiment

      def self.choose!(experiment, **opts)
        new(experiment).choose!(**opts)
      end

      def initialize(experiment)
        @experiment = experiment
      end

      def choose!(**opts)
        variants.sample
      end

      private

      def variants
        groups = experiment.variants.group_by(&:participants)
        groups.min_by { |c,g| c }.last
      end
    end
  end
end
