require "canfig"
require "redis"
require "trail_guide/participant"
require "trail_guide/variant"
require "trail_guide/experiment"
require "trail_guide/catalog"
require "trail_guide/engine"

module TrailGuide
  include Canfig::Module

  configure do |config|
    config.redis = ENV['REDIS_URL']
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
