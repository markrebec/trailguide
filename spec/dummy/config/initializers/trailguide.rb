require "redis-namespace"

TrailGuide.configure do |config|
  config.redis = Redis::Namespace.new(
    :trailguide_dummy,
    redis: Redis.new(url: ENV['REDIS_URL'])
  )

  config.adapter = :multi
  config.allow_multiple_experiments = true
  config.cleanup_participant_experiments = false
end

TrailGuide::Experiment.configure do |config|
end

TrailGuide::Admin.configure do |config|
  config.peek_parameter = :peek
end
