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

      def experiment_peekable?(experiment)
        return false unless TrailGuide::Admin.configuration.peek_parameter
        return false unless experiment.running?
        return false if experiment.target_sample_size_reached?
        return true
      end
      helper_method :experiment_peekable?

      def experiment_peeking?(experiment)
        params[:peek] == experiment.experiment_name.to_s
      end
      helper_method :experiment_peeking?

      def experiment_metrics_visible?(experiment)
        return true unless experiment.running?
        return true if params[:peek] == experiment.experiment_name.to_s
        return true if experiment.target_sample_size_reached?
        return false
      end
      helper_method :experiment_metrics_visible?

      def experiment_metric(experiment, metric)
        return metric if experiment_metrics_visible?(experiment)
        return '?'
      end
      helper_method :experiment_metric

      def peek_url(experiment, *args, **opts)
        trail_guide_admin.experiments_url(*args, opts.merge({TrailGuide::Admin.configuration.peek_parameter => experiment.experiment_name, anchor: experiment.experiment_name}))
      end
      helper_method :peek_url
    end
  end
end
