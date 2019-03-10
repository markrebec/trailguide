TrailGuide.configure do |config|
  config.redis = ENV['REDIS_URL']           # url string or Redis object
  config.disabled = false                   # globally disable trailguide (returns control everywhere)
  config.override_parameter = :experiment   # request param for overriding/previewing variants
  config.allow_multiple_experiments = false # true = allowed / false = not allowed / :control = only if in control for all other experments
  config.adapter = :cookie                  # :redis / :cookie / :session / :anonymous / :multi / :unity
  config.filtered_user_agents = []          # array or proc -> { return [...] }
  config.filtered_ip_addresses = []         # array or proc -> { return [...] }

  # callback when your adapter fails to initialize and trailguide falls back
  # to the anonymous adapter
  config.on_adapter_failover = -> (adapter, error) do
    Rails.logger.error("#{error.class.name}: #{error.message}")
  end

  # default request filter logic uses the configured filtered IPs and user
  # agents above
  config.request_filter = -> (context) do
    is_preview? ||
      is_filtered_user_agent? ||
      is_filtered_ip_address?
  end
end

TrailGuide::Experiment.configure do |config|
  config.algorithm = :weighted              # the algorithm to use for this experiment

  config.start_manually = true              # if false experiments will start the first time they're encountered
  config.reset_manually = true              # if false participants will reset and be able to re-enter the experiment upon conversion

  config.store_override = false             # if true using overrides to preview experiments will enter participants into that variant
  config.track_override = false             # if true using overrides to preview experiments will increment variant participants
  config.track_winner_conversions = false   # if true continues to track conversions after a winner has been selected
  config.allow_multiple_conversions = false # if true tracks multiple participant conversions for the same goal 
  config.allow_multiple_goals = false       # if true allows participants to convert more than one goal

  config.skip_request_filter = false        # if true requests that would otherwise be filtered based on your request_filter config above (i.e. bots) will be allowed through to this experiment

  # callback when connecting to redis fails and trailguide falls back to always
  # returning control variants
  config.on_redis_failover = -> (experiment, error) do
    Rails.logger.error("#{error.class.name}: #{error.message}")
  end

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
