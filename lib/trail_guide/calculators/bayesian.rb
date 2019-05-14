module TrailGuide
  module Calculators
    class Bayesian < Calculator
      def initialize(*args, **opts)
        super(*args, **opts)
      end

      def pdf(variant, z)
        x = variant.conversions
        n = variant.participants
        if defined?(Distribution)
          Distribution::Beta.pdf(z, x+1, n-x+1)
        elsif defined?(Rubystats)
          Rubystats::BetaDistribution.new(x+1, n-x+1).pdf(z)
        else
          raise NoBetaDistributionCalculator, "Unable to calculate beta distribution: could not find the 'distribution' or 'rubystats' gems. Please add either the 'distribution' or 'rubystats' gems to your gemfile and make sure to require them in your application."
        end
      end

      def cdf(variant, z)
        x = variant.conversions
        n = variant.participants
        if defined?(Distribution)
          Distribution::Beta.cdf(z, x+1, n-x+1)
        elsif defined?(Rubystats)
          Rubystats::BetaDistribution.new(x+1, n-x+1).cdf(z)
        else
          raise NoBetaDistributionCalculator, "Unable to calculate beta distribution: could not find the 'distribution' or 'rubystats' gems. Please add either the 'distribution' or 'rubystats' gems to your gemfile and make sure to require them in your application."
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
      rescue NameError => e
        raise NoZScoreCalculator, "Unable to calculate z-score: could not find the 'integration' gem. Please add the 'integration' gem to your gemfile and make sure to require it in your application."
      end

      def calculate!
        variants.each do |variant|
          expvar = experiment.variants.find { |var| var.name == variant.name }
          vprob = variant_probability(variant)
          variant.probability = vprob
          variant.significance = TrailGuide::Calculators::SIGNIFICANT_PROBABILITIES.find { |pct| vprob >= pct } || 0

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
