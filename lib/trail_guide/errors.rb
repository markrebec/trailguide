module TrailGuide
  class InvalidGoalError < ArgumentError; end
  class UnsupportedContextError < NoMethodError; end
  class NoExperimentsError < ArgumentError; end
  class TooManyExperimentsError < ArgumentError; end
  class NoVariantMethodError < NoMethodError; end
end
