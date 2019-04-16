module TrailGuide
  class Engine < ::Rails::Engine
    isolate_namespace TrailGuide

    class << self
      attr_accessor :routes_loaded
    end

    config.generators do |g|
      g.test_framework = :rspec
    end

    initializer "trailguide" do |app|
      TrailGuide::Catalog.load_experiments!
      if TrailGuide.configuration.include_helpers
        ActionController::Base.send :include, TrailGuide::Helper
        ActionController::Base.helper TrailGuide::Helper
      end
    end
  end
end
