require "canfig"
require "redis"
require "trail_guide/version"
require "trail_guide/config"
require "trail_guide/errors"
require "trail_guide/adapters"
require "trail_guide/algorithms"
require "trail_guide/metrics"
require "trail_guide/calculators"
require "trail_guide/participant"
require "trail_guide/variant"
require "trail_guide/variants"
require "trail_guide/experiment"
require "trail_guide/combined_experiment"
require "trail_guide/catalog"
require "trail_guide/helper"
require "trail_guide/engine"
require "trail_guide/admin"

module TrailGuide
  include Canfig::Module
  @@configuration = TrailGuide::Config.new

  SCHEDULE_DATE_FORMAT = "%m/%d/%Y %I:%M %p %Z"

  class << self
    delegate :logger, :redis, :redis_client, to: :configuration
  end
end
