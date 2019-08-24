module TrailGuide
  class Engine < ::Rails::Engine
    isolate_namespace TrailGuide

    config.generators do |g|
      g.test_framework = :rspec
    end

    paths["config/routes.rb"] = "config/routes/engine.rb"

    initializer "trailguide" do |app|
      TrailGuide::Catalog.load_experiments!(**TrailGuide.configuration.paths.to_h)
      if TrailGuide.configuration.include_helpers
        ActionController::Base.send :include, TrailGuide::Helper
        ActionController::Base.helper TrailGuide::Helper
      end
    end
  end
end
