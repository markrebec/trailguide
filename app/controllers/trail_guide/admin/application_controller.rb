module TrailGuide
  module Admin
    class ApplicationController < ::ApplicationController
      protect_from_forgery with: :exception

      def preview_url(variant, *args, **opts)
        config_url = variant.experiment.configuration.preview_url
        opts = opts.merge({experiment: {variant.experiment.experiment_name => variant.name}})
        if config_url.respond_to?(:call)
          main_app.instance_exec *args, **opts, &config_url
        elsif config_url.is_a?(Symbol)
          main_app.send(config_url, *args, **opts)
        else
          config_url.to_s + "?experiment[#{variant.experiment.experiment_name}]=#{variant.name}"
        end
      end
      helper_method :preview_url
    end
  end
end
