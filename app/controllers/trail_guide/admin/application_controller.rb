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
        return false unless experiment.started? && !experiment.stopped? && !experiment.winner?
        return false if experiment.target_sample_size_reached?
        return true
      end
      helper_method :experiment_peekable?

      def experiment_peeking?(experiment)
        params[TrailGuide::Admin.configuration.peek_parameter] == experiment.experiment_name.to_s
      end
      helper_method :experiment_peeking?

      def experiment_metrics_visible?(experiment)
        return true unless experiment.started? && !experiment.stopped? && !experiment.winner?
        return true if params[TrailGuide::Admin.configuration.peek_parameter] == experiment.experiment_name.to_s
        return true if experiment.target_sample_size_reached?
        return false
      end
      helper_method :experiment_metrics_visible?

      def experiment_metric(experiment, metric)
        return helpers.number_with_delimiter(metric) if experiment_metrics_visible?(experiment)
        return helpers.content_tag('span', nil, class: 'fas fa-eye-slash', data: {toggle: 'tooltip'}, title: "metrics are hidden until this experiment reaches it's target sample size")
      end
      helper_method :experiment_metric

      def peek_url(experiment, *args, **opts)
        trail_guide_admin.experiment_url(experiment.experiment_name, *args, opts.merge({TrailGuide::Admin.configuration.peek_parameter => experiment.experiment_name}))
      end
      helper_method :peek_url

      def experiment_color(experiment)
        if experiment.winner?
          'primary'
        elsif experiment.started?
          if experiment.stopped?
            'danger'
          elsif experiment.paused?
            'warning'
          else
            'success'
          end
        elsif experiment.scheduled?
          'info'
        else
          'secondary'
        end
      end
      helper_method :experiment_color
    end
  end
end
