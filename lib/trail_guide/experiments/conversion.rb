module TrailGuide
  module Experiments
    module Conversion
      def convert!(checkpoint=nil, metadata: nil)
        if !started?
          return false unless enable_calibration?
          variant = participant.variant
          return false unless variant.present? && variant == control
        else
          return false unless running?
          variant = participant.variant
          return false unless variant.present?

          if winner?
            return false unless track_winner_conversions? && variant == winner
          end
        end

        if checkpoint.nil?
          raise InvalidGoalError, "You must provide a valid goal checkpoint for `#{experiment_name}`." unless goals.empty?
        else
          goal = goals.find { |g| g == checkpoint }
          raise InvalidGoalError, "Invalid goal checkpoint `#{checkpoint}` for `#{experiment_name}`." if goal.nil?
          checkpoint = goal
        end

        # TODO eventually allow progressing through funnel checkpoints towards goals
        if participant.converted?(checkpoint)
          return false unless (checkpoint.nil? && allow_multiple_conversions?) || (checkpoint.present? && checkpoint.allow_multiple_conversions?)
        elsif participant.converted?
          return false unless allow_multiple_goals?
        end
        return false unless allow_conversion?(variant, checkpoint, metadata)

        # TODO only reset if !reset_manually? AND they've converted all goals if
        # allow_multiple_goals? is set
        # TODO what should happen when allow_multiple_conversions? and !reset_manually?
        # TODO eventually only reset if we're at the final goal in a funnel
        participant.converted!(variant, checkpoint, reset: !reset_manually?)
        variant.increment_conversion!(checkpoint)
        if checkpoint.nil?
          run_callbacks(:on_convert, checkpoint, variant, participant, metadata)
        else
          checkpoint.run_callbacks(:on_convert, self, variant, participant, metadata)
        end
        variant
      rescue Errno::ECONNREFUSED, Redis::BaseError, SocketError => e
        run_callbacks(:on_redis_failover, e)
        return false
      end

      def allow_conversion?(variant, checkpoint=nil, metadata=nil)
        if checkpoint.nil?
          return true if callbacks[:allow_conversion].empty?
          # TODO why pass checkpoint through here if checkpoints are handled by their own method? it will always be nil here given current logic
          run_callbacks(:allow_conversion, true, checkpoint, variant, participant, metadata)
        else
          checkpoint.allow_conversion?(self, variant, metadata)
        end
      end
    end
  end
end
