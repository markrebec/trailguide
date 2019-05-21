module TrailGuide
  module Calculators
    class Score < Calculator
      # array of [z-score, percentage]
      def self.z_score_probabilities
        @@z_score_probabilities ||= begin
          avg = 50.0
          norm_dist = []
          (0.0..3.1).step(0.01) { |x| norm_dist << [x, avg += 1 / Math.sqrt(2 * Math::PI) * Math::E ** (-x ** 2 / 2)] }
          norm_dist
        end
      end

      def self.all_probabilities
        @@all_probabilities ||= (0.0..100.0).step(0.1).map { |pct| [z_score_probabilities.find { |x,a| a >= pct }.first, pct] }.reverse
      end

      def self.significant_probabilities
        @@significant_probabilities ||= TrailGuide::Calculators::SIGNIFICANT_PROBABILITIES.map { |pct| [z_score_probabilities.find { |x,a| a >= pct }.first, pct] }.reverse
      end

      def self.z_score_probability(score)
        score = score.abs
        probability = all_probabilities.find { |z,p| score >= z }
        probability ? probability.last : 0
      end

      def self.significant_probability(score)
        score = score.abs
        probability = significant_probabilities.find { |z,p| score >= z }
        probability ? probability.last : 0
      end

      def calculate!
        pc = base.measure
        nc = base.superset
        variants_with_conversion.each do |var|
          p = var.measure
          n = var.superset
          z_score = (p - pc) / ((p * (1-p)/n) + (pc * (1-pc)/nc)).abs ** 0.5

          var.z_score = z_score
          var.probability = self.class.z_score_probability(z_score)
          var.probability = -(var.probability) if var.z_score.negative?
          var.significance = self.class.significant_probability(z_score)
          var.significance = -(var.significance) if var.z_score.negative?

          #if worst && var.measure > worst.measure
          #  var.difference = (var.measure - worst.measure) / worst.measure * 100
          #end
          if base
            if var.measure > base.measure
              var.difference = (var.measure - base.measure) / base.measure * 100
            elsif base.measure > var.measure
              var.difference = -((base.measure - var.measure) / base.measure * 100)
            else
              var.difference = 0
            end
          end
        end

        @choice = best && best.probability >= probability ? best : nil

        self
      end
    end
  end
end
