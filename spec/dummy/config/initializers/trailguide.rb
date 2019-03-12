require "redis-namespace"

TrailGuide.configure do |config|
  config.redis = Redis::Namespace.new(
    :trailguide_dummy,
    redis: Redis.new(url: ENV['REDIS_URL'])
  )
end

TrailGuide::Experiment.configure do |config|
end

TrailGuide::Admin.configure do |config|
end
