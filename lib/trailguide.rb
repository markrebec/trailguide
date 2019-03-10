require "canfig"
require "redis"
require "trail_guide/config"
require "trail_guide/errors"
require "trail_guide/adapters"
require "trail_guide/algorithms"
require "trail_guide/participant"
require "trail_guide/variant"
require "trail_guide/experiment"
require "trail_guide/combined_experiment"
require "trail_guide/catalog"
require "trail_guide/helper"
require "trail_guide/engine"
require "trail_guide/version"

module TrailGuide
  include Canfig::Module
  @@configuration = TrailGuide::Config.new

  class << self
    delegate :redis, to: :configuration
  end

  configure do |config|
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
end
