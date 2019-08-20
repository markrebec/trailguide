module TrailGuide
  module Algorithms
    class Distributed < Algorithm
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
