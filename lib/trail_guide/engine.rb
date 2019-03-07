module TrailGuide
  class Engine < ::Rails::Engine
    isolate_namespace TrailGuide

    config.generators do |g|
      g.test_framework = :rspec
    end

    initializer "trailguide" do |app|
      TrailGuide::Catalog.load_experiments!
      ActionController::Base.send :include, TrailGuide::Helper
      ActionController::Base.helper TrailGuide::Helper
    end
  end
end
