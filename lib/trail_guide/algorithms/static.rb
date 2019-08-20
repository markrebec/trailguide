module TrailGuide
  module Algorithms
    class Static < Algorithm
      def self.choose!(experiment, metadata:, &block)
        new(experiment, &block).choose!(metadata: metadata)
      end

      def initialize(experiment=nil, &block)
        @block = block
        super(experiment)
      end

      def new(experiment)
        self.class.new(experiment, &@block)
      end

      def choose!(metadata:)
        return experiment.control unless metadata.present?

        experiment.variants.find do |variant|
          @block.call(variant.metadata, metadata)
        end || experiment.control
      end
    end
  end
end
