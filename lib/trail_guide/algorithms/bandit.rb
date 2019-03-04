require 'simple-random'

module TrailGuide
  module Algorithms
    class Bandit
      attr_reader :experiment

      def self.choose!(experiment, **opts)
        new(experiment).choose!(**opts)
      end

      def initialize(experiment)
        @experiment = experiment
      end

      def choose!(**opts)
        guess = best_guess
        experiment.variants.find { |var| var == guess }
      end

      private

      def best_guess
        @best_guess ||= begin
          guesses = {}
          experiment.variants.each do |variant|
            guesses[variant.name] = arm_guess(variant.participants, variant.converted)
          end
          gmax = guesses.values.max
          best = guesses.keys.select { |name| guesses[name] ==  gmax }
          best.sample
        end
      end

      def arm_guess(participants, conversions)
        a = [participants, 0].max
        b = [(participants - conversions), 0].max
        s = SimpleRandom.new
        s.set_seed
        s.beta(a+fairness_constant, b+fairness_constant)
      end

      def fairness_constant
        7
      end
    end
  end
end
