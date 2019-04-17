module TrailGuide
  module Admin
    class Engine < ::Rails::Engine
      isolate_namespace TrailGuide::Admin

      config.generators do |g|
        g.test_framework = :rspec
      end

      paths["config/routes.rb"] = "config/routes/admin.rb"
    end
  end
end
