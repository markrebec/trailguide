require "canfig"
require "redis"
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
    config.start_manually = false
    config.reset_manually = false
    config.store_override = false
    config.override_parameter = :experiment
    config.allow_multiple_experiments = true # false / :control
    config.algorithm = :weighted
    config.adapter = :cookie

    config.on_experiment_choose = nil  # -> (experiment, variant) { ... }
    config.on_experiment_convert = nil # -> (experiment, variant, checkpoint) { ... }

    config.on_experiment_start = nil   # -> (experiment) { ... }
    config.on_experiment_stop = nil    # -> (experiment) { ... }
    config.on_experiment_reset = nil   # -> (experiment) { ... }
    config.on_experiment_delete = nil  # -> (experiment) { ... }
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
