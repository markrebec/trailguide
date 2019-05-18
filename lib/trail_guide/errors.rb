module TrailGuide
  class InvalidGoalError < ArgumentError; end
  class UnsupportedContextError < NoMethodError; end
  class TooManyExperimentsError < ArgumentError; end
  class NoVariantMethodError < NoMethodError; end

  class NoExperimentsError < ArgumentError
    def initialize(key)
      super("Could not find any experiments matching '#{key}'")
    end
  end
end
