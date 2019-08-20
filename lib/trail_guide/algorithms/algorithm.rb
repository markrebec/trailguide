module TrailGuide
  module Algorithms
    class Algorithm
      attr_reader :experiment

      def self.choose!(experiment, **opts)
        new(experiment).choose!(**opts)
      end

      def initialize(experiment)
        @experiment = experiment
      end

      def choose!(**opts)
        raise NotImplementedError, 'You must define a `#choose!(**opts)` method for your algorithm'
      end
    end
  end
end
