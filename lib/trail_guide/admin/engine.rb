module TrailGuide
  module Admin
    class Engine < ::Rails::Engine
      isolate_namespace TrailGuide::Admin

    class << self
      attr_accessor :routes_loaded
    end

      config.generators do |g|
        g.test_framework = :rspec
      end
    end
  end
end
