module TrailGuide
  class Engine < ::Rails::Engine
    isolate_namespace TrailGuide

    config.generators do |g|
      g.test_framework = :rspec
    end
  end
end
