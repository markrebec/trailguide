module TrailGuide
  module Admin
    class Config < Canfig::Config
      DEFAULT_KEYS = [
        :title, :subtitle, :experiment_user, :peek_parameter, :date_format, :time_zone
      ].freeze

      def initialize(*args, **opts, &block)
        args = args.concat(DEFAULT_KEYS)
        super(*args, **opts, &block)
      end

      def time_zone
        self[:time_zone] ||= 'UTC'
        self[:time_zone] = self[:time_zone].call if self[:time_zone].respond_to?(:call)
        self[:time_zone] = ActiveSupport::TimeZone[self[:time_zone]] unless self[:time_zone].is_a?(ActiveSupport::TimeZone)
        self[:time_zone]
      end
    end
  end
end
