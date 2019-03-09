require "trail_guide/experiments/base"

module TrailGuide
  class Experiment < Experiments::Base

    configure do |config|
      config.start_manually = true
      config.reset_manually = true
      config.store_override = false
      config.track_override = false
      config.track_winner_conversions = false
      config.allow_multiple_conversions = false
      config.allow_multiple_goals = false
      config.algorithm = :weighted

      config.on_redis_failover = nil        # -> (experiment, error) { ... }

      config.on_choose = nil     # -> (experiment, variant, metadata) { ... }
      config.on_use = nil        # -> (experiment, variant, metadata) { ... }
      config.on_convert = nil    # -> (experiment, variant, checkpoint, metadata) { ... }

      config.on_start = nil      # -> (experiment) { ... }
      config.on_stop = nil       # -> (experiment) { ... }
      config.on_resume = nil     # -> (experiment) { ... }
      config.on_reset = nil      # -> (experiment) { ... }
      config.on_delete = nil     # -> (experiment) { ... }
      config.on_winner = nil     # -> (experiment, winner) { ... }

      config.rollout_winner = nil       # -> (experiment, winner) { ... return variant }
    end

    def self.inherited(child)
      child.instance_variable_set :@configuration, Experiments::Config.new(child, inherit: self.configuration)
      TrailGuide.catalog.register(child)
    end
  end
end
