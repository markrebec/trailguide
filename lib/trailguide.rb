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
    config.disabled = false

    config.redis = ENV['REDIS_URL']

    config.algorithm = TrailGuide::Algorithms::Weighted

    # TODO use cookie adapter by default?
    config.adapter = TrailGuide::Adapters::Participants::Redis
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
