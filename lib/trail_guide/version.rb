module TrailGuide
  module Version
    MAJOR = 0
    MINOR = 4
    PATCH = 5
    VERSION = "#{MAJOR}.#{MINOR}.#{PATCH}"

    class << self
      def inspect
        VERSION
      end
    end
  end
end
