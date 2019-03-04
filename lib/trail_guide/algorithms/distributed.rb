module TrailGuide
  module Algorithms
    class Distributed
      attr_reader :experiment

      def self.choose!(experiment)
        new(experiment).choose!
      end

      def initialize(experiment)
        @experiment = experiment
      end

      def choose!
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
