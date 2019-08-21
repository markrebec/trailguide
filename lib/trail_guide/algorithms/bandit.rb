require 'simple-random'

module TrailGuide
  module Algorithms
    class Bandit < Algorithm
      def choose!(**opts)
        variants.find { |var| var == best_guess }
      end

      private

      def guesses
        @guesses ||= variants.map do |variant|
          [variant.name, arm_guess(variant.participants, variant.converted)]
        end.to_h
      end

      def best_guess
        @best_guess ||= begin
          gmax = guesses.values.max
          best = guesses.keys.select { |name| guesses[name] == gmax }
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
