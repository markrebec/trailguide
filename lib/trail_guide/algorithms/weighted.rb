module TrailGuide
  module Algorithms
    class Weighted < Algorithm
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
