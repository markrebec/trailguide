module TrailGuide
  module Admin
    class Config < Canfig::Config
      DEFAULT_KEYS = [
        :title, :subtitle, :peek_parameter, :date_format, :time_zone
      ].freeze

      def initialize(*args, **opts, &block)
        args = args.concat(DEFAULT_KEYS)
        super(*args, **opts, &block)
      end
    end
  end
end
