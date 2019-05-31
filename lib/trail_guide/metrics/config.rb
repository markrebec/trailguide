module TrailGuide
  module Metrics
    class Config < Canfig::Config
      attr_reader :metric

      INHERIT_KEYS = [ :allow_multiple_conversions, :allow_conversion, :on_convert ]
      CALLBACK_KEYS = [ :allow_conversion, :on_convert ]

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

      def callbacks
        to_h.slice(*CALLBACK_KEYS).map { |k,v| [k, [v].flatten.compact] }.to_h
      end

      def allow_multiple_conversions?
        !!allow_multiple_conversions
      end

      # TODO do we allow a method here? do we call it on the experiment?
      def allow_conversion(meth=nil, &block)
        self[:allow_conversion] ||= []
        self[:allow_conversion] << (meth || block)
      end

      def on_convert(meth=nil, &block)
        self[:on_convert] ||= []
        self[:on_convert] << (meth || block)
      end
    end
  end
end
