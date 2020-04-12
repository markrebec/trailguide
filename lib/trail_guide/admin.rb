require "trail_guide/admin/config"
require "trail_guide/admin/engine"

module TrailGuide
  module Admin
    class << self
      def configuration
        @configuration ||= Admin::Config.new
      end

      def configure(*args, &block)
        configuration.configure(*args, &block)
      end
    end
  end
end
