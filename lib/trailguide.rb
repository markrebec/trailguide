require "canfig"
require "redis"
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

  configure do |config|
    config.redis = ENV['REDIS_URL']
    config.disabled = false
    config.override_parameter = :experiment
    config.allow_multiple_experiments = true  # false / :control
    config.adapter = :multi
    config.on_adapter_failover = nil          # -> (adapter, error) { ... }

    config.filtered_user_agents = []
    config.filtered_ip_addresses = []
    config.request_filter = -> (context) do
      is_preview? ||
        is_filtered_user_agent? ||
        is_filtered_ip_address?
    end

    def filtered_user_agents
      @filtered_user_agents ||= begin
        uas = @state[:filtered_user_agents]
        uas = uas.call if uas.respond_to?(:call)
        uas
      end
    end

    def filtered_ip_addresses
      @filtered_ip_addresses ||= begin
        ips = @state[:filtered_ip_addresses]
        ips = ips.call if ips.respond_to?(:call)
        ips
      end
    end
  end

  def self.redis
    @redis ||= begin
      if ['Redis', 'Redis::Namespace'].include?(configuration.redis.class.name)
        configuration.redis
      else
        Redis.new(url: configuration.redis)
      end
    end
  end
end
