module TrailGuide
  module Algorithms
    class Static < Algorithm
      def self.choose!(experiment, metadata: nil, &block)
        new(experiment, &block).choose!(metadata: metadata)
      end

      def initialize(experiment=nil, &block)
        @block = block
        super(experiment)
      end

      def new(experiment)
        TrailGuide.logger.warn "WARNING: Using the Static algorithm for an experiment which is configured with sticky_assignment. You should either use a different algorithm or configure sticky_assignment for the `#{experiment.experiment_name}` experiment." if experiment.configuration.sticky_assignment?
        self.class.new(experiment, &@block)
      end

      def choose!(metadata: nil)
        return control unless metadata.present?

        variant = variants.find do |variant|
          @block.call(variant.metadata, metadata)
        end
        
        variant || control
      rescue => e
        TrailGuide.logger.error "#{e.class.name}: #{e.message}"
        TrailGuide.logger.error e.backtrace.first
        control
      end
    end
  end
end
