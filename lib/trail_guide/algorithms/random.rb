module TrailGuide
  module Algorithms
    class Random < Algorithm
      def choose!(**opts)
        variants.sample
      end
    end
  end
end
