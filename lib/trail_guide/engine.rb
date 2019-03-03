module TrailGuide
  class Engine < ::Rails::Engine
    isolate_namespace TrailGuide

    config.generators do |g|
      g.test_framework = :rspec
    end

    initializer "trailguide" do |app|
      # TODO temporary until we have real configs
      Dir[Rails.root.join("app/experiments/**/*.rb")].each { |f| require f }
    end
  end
end
