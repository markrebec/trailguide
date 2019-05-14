module TrailGuide
  module Calculators
    SIGNIFICANT_PROBABILITIES = [10, 50, 75, 90, 95, 99, 99.9]
    DEFAULT_PROBABILITY = 90

    class Calculator
      attr_reader :experiment, :goal, :probability, :choice

      def initialize(experiment, probability=TrailGuide::Calculators::DEFAULT_PROBABILITY, base: :default, goal: nil, participants: nil)
        @experiment = experiment
        @probability = probability
        @base_type = base
        @goal = goal
        @participants = participants
      end

      def variants
        @variants ||= experiment.variants.map do |variant|
          participants = @participants ? variant.converted(@participants) : variant.participants
          converts = variant.converted(goal)
          measure = converts.to_f / participants.to_f

          Struct.new(:name, :control, :participants, :conversions, :measure,
                     :z_score, :difference, :probability, :significance)
            .new(variant.name, variant.control?, participants, converts, measure, 0, 0, 0, nil)
        end.sort_by { |v| v.measure }
      end

      def variants_with_conversion
        @variants_with_conversion ||= variants.select { |variant| variant.measure > 0.0 }
      end

      def base
        @base ||= case @base_type
          when :control
            # use the control as the "base"
            variants.find { |variant| variant.control }
          else
            # use the second-best converting as the "base" (default behavior)
            variants[-2]
        end
      end

      def best
        @best ||= variants_with_conversion.last
      end

      def worst
        @worst ||= variants_with_conversion.first
      end

      def calculate!
        raise NotImplementedError, "You must define a calculate! method on your calculator class"
      end
    end
  end
end
