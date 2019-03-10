require "trail_guide/experiments/base"

module TrailGuide
  class Experiment < Experiments::Base

    configure do |config|
      config.start_manually = true              # if false experiments will start the first time they're encountered
      config.reset_manually = true              # if false participants will reset and be able to re-enter the experiment upon conversion
      config.store_override = false             # if true using overrides to preview experiments will enter participants into that variant
      config.track_override = false             # if true using overrides to preview experiments will increment variant participants
      config.track_winner_conversions = false   # if true continues to track conversions after a winner has been selected
      config.allow_multiple_conversions = false # if true tracks multiple participant conversions for the same goal 
      config.allow_multiple_goals = false       # if true allows participants to convert more than one goal
      config.algorithm = :weighted              # the algorithm to use for this experiment

      #config.on_redis_failover =  -> (experiment, error) { ... }

      #config.on_choose =          -> (experiment, variant, metadata) { ... }
      #config.on_use =             -> (experiment, variant, metadata) { ... }
      #config.on_convert =         -> (experiment, variant, checkpoint, metadata) { ... }

      #config.on_start =           -> (experiment) { ... }
      #config.on_stop =            -> (experiment) { ... }
      #config.on_resume =          -> (experiment) { ... }
      #config.on_reset =           -> (experiment) { ... }
      #config.on_delete =          -> (experiment) { ... }
      #config.on_winner =          -> (experiment, winner) { ... }

      #config.rollout_winner =     -> (experiment, winner) { ... return variant }
    end

    def self.inherited(child)
      child.instance_variable_set :@configuration, Experiments::Config.new(child, inherit: self.configuration)
      TrailGuide.catalog.register(child)
    end
  end
end
