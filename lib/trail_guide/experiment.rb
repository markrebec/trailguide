require "trail_guide/experiments/base"

module TrailGuide
  class Experiment < Experiments::Base
    def self.inherited(child)
      TrailGuide.catalog.register(child)
    end
  end
end
