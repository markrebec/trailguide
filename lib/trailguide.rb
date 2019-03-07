require "canfig"
require "redis"
require "trail_guide/errors"
require "trail_guide/adapters"
require "trail_guide/algorithms"
require "trail_guide/participant"
require "trail_guide/variant"
require "trail_guide/experiment"
require "trail_guide/catalog"
require "trail_guide/helper"
require "trail_guide/engine"

module TrailGuide
  include Canfig::Module

  configure do |config|
    config.redis = ENV['REDIS_URL']
    config.disabled = false
    config.start_manually = true
    config.reset_manually = true
    config.store_override = false
    config.track_override = false
    config.override_parameter = :experiment
    config.algorithm = :weighted
    config.adapter = :multi
    config.allow_multiple_experiments = true # false / :control
    config.track_winner_conversions = false
    config.allow_multiple_conversions = false
    config.allow_multiple_goals = false

    config.on_experiment_choose = nil  # -> (experiment, variant, metadata) { ... }
    config.on_experiment_use = nil     # -> (experiment, variant, metadata) { ... }
    config.on_experiment_convert = nil # -> (experiment, variant, checkpoint, metadata) { ... }

    config.on_experiment_start = nil   # -> (experiment) { ... }
    config.on_experiment_stop = nil    # -> (experiment) { ... }
    config.on_experiment_resume = nil  # -> (experiment) { ... }
    config.on_experiment_reset = nil   # -> (experiment) { ... }
    config.on_experiment_delete = nil  # -> (experiment) { ... }

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

  def self.catalog
    TrailGuide::Catalog.catalog
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
