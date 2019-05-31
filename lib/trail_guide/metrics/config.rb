module TrailGuide
  module Metrics
    class Config < Canfig::Config
      attr_reader :metric

      INHERIT_KEYS = [
        # configs
        :allow_multiple_conversions, :track_winner_conversions,
        # callbacks
        :allow_conversion, :on_convert
      ]

      def initialize(metric, *args, **opts, &block)
        @metric = metric

        opts = INHERIT_KEYS.map do |key|
          val = experiment.configuration[key]
          val = val.dup if val
          [ key, val ]
        end.to_h.merge(opts)

        super(*args, **opts, &block)
      end

      def experiment
        metric.experiment
      end
    end
  end
end
