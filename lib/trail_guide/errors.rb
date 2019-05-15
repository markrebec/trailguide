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

  module Calculators
    class NoBetaDistributionLibrary < LoadError
      def initialize(type=nil)
        if type
          super("Beta distribution library not found: #{type.to_s}! You must add the '#{type.to_s}' gem to your Gemfile in order to run this analysis with it.")
        else
          super("No beta distribution library found! You must add either the 'distribution' or 'rubystats' gems to your Gemfile in order to run this analysis.")
        end
      end
    end

    class UnknownBetaDistributionLibrary < ArgumentError
      def initialize(type)
        super("Unknown beta distribution library: #{type.to_s}! The libraries available for calculating beta distribution are 'rubystats' (default) or 'distribution'.")
      end
    end

    class NoIntegrationLibrary < LoadError
      def initialize(msg=nil)
        super(msg || "No integration library found! You must add the 'integration' gem to your gemfile in order to run this analysis.")
      end
    end
  end
end
