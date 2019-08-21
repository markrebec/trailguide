module TrailGuide
  module Algorithms
    class Weighted < Algorithm
      def choose!(**opts)
        reference = rand * variants.sum(&:weight)
        variants.each do |variant|
          return variant if variant.weight >= reference
          reference -= variant.weight
        end
      end
    end
  end
end
