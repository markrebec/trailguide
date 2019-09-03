module TrailGuide
  module Experiments
    module Results

      def self.included(base)
        base.send :extend, ClassMethods
      end

      module ClassMethods
        def winner
          winner = adapter.get(:winner)
          return variants.find { |var| var == winner } if winner
        end

        def participants
          variants.sum(&:participants)
        end

        def converted(checkpoint=nil)
          variants.sum { |var| var.converted(checkpoint) }
        end

        def unconverted
          participants - converted
        end

        def target_sample_size_reached?
          return true unless configuration.target_sample_size
          return true if participants >= configuration.target_sample_size
          return false
        end
      end

      def winner
        @winner ||= self.class.winner
      end

      def winning_variant
        return nil unless winner?
        run_callbacks(:rollout_winner, winner, participant)
      end
    end
  end
end
