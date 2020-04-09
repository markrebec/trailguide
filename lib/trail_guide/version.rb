module TrailGuide
  module Version
    MAJOR = 0
    MINOR = 3
    PATCH = 4
    VERSION = "#{MAJOR}.#{MINOR}.#{PATCH}"

    class << self
      def inspect
        VERSION
      end
    end
  end
end
