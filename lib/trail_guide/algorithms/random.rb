module TrailGuide
  module Algorithms
    class Random < Algorithm
      def choose!(**opts)
        experiment.variants.sample
      end
    end
  end
end
