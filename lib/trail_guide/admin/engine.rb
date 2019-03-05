module TrailGuide
  module Admin
    class Engine < ::Rails::Engine
      isolate_namespace TrailGuide::Admin

      config.generators do |g|
        g.test_framework = :rspec
      end
    end
  end
end

load TrailGuide::Admin::Engine.root.join("config/admin/routes.rb")