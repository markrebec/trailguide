require "trail_guide/experiments/base"

module TrailGuide
  class Experiment < Experiments::Base

    def self.inherited(child)
      child.instance_variable_set :@configuration, Experiments::Config.new(child, inherit: self.configuration)
    end
  end
end
