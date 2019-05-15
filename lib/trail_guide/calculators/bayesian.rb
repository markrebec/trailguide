module TrailGuide
  module Calculators
    class Bayesian < Calculator
      def self.enabled?
        !!(defined?(::Integration) && (defined?(::Rubystats) || defined?(::Distribution)))
      end

      attr_reader :beta

      def initialize(*args, beta: nil, **opts)
        raise NoIntegrationLibrary if !defined?(::Integration)

        if beta.nil?
          # prefer rubystats if not specified
          if defined?(::Rubystats)
            beta = :rubystats
          elsif defined?(::Distribution)
            beta = :distribution
          else
            raise NoBetaDistributionLibrary
          end
        end

        case beta.to_sym
        when :distribution
          raise NoBetaDistributionLibrary, beta unless defined?(::Distribution)
          TrailGuide.logger.debug "Using Distribution::Beta to calculate beta distributions"
          TrailGuide.logger.debug "GSL detected, Distribution::Beta will use GSL for better performance" if defined?(::GSL)
        when :rubystats
          raise NoBetaDistributionLibrary, beta unless defined?(::Rubystats)
          TrailGuide.logger.debug "Using Rubystats::BetaDistribution to calculate beta distributions"
        else
          raise UnknownBetaDistributionLibrary, beta
        end

        super(*args, **opts)
        @beta = beta.to_sym
      end

      def pdf(variant, z)
        x = variant.subset
        n = variant.superset
        if beta == :distribution
          Distribution::Beta.pdf(z, x+1, n-x+1)
        else
          Rubystats::BetaDistribution.new(x+1, n-x+1).pdf(z)
        end
      end

      def cdf(variant, z)
        x = variant.subset
        n = variant.superset
        if beta == :distribution
          Distribution::Beta.cdf(z, x+1, n-x+1)
        else
          Rubystats::BetaDistribution.new(x+1, n-x+1).cdf(z)
        end
      end

      def variant_probability(variant)
        Integration.integrate(0, 1, tolerance: 1e-4) do |z|
          vpdf = pdf(variant, z)
          variants.each do |var|
            next if var == variant
            vpdf = vpdf * cdf(var, z)
          end
          vpdf
        end * 100.0
      end

      def calculate!
        variants.each do |variant|
          expvar = experiment.variants.find { |var| var.name == variant.name }
          vprob = variant_probability(variant)
          variant.probability = vprob
          variant.significance = TrailGuide::Calculators::SIGNIFICANT_PROBABILITIES.reverse.find { |pct| vprob >= pct } || 0

          if worst && variant.measure > worst.measure
            variant.difference = (variant.measure - worst.measure) / worst.measure * 100
          end
        end

        @choice = best && best.probability >= probability ? best : nil

        self
      end
    end
  end
end
