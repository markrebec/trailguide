require "trail_guide/admin/engine"

module TrailGuide
  module Admin
    include Canfig::Module

    configure do |config|
      config.title = 'TrailGuide'
      config.subtitle = 'Experiments and A/B Tests'
    end
  end
end
