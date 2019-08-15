require "trail_guide/experiments/config"

module TrailGuide
  module Experiments
    class CombinedConfig < Config
      def initialize(experiment, *args, **opts, &block)
        args.push(:parent)
        super(experiment, *args, **opts, &block)
      end

      def parent
        self[:parent]
      end
    end
  end
end
