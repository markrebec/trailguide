module TrailGuide
  module Experiments
    module Enrollment
      def algorithm
        @algorithm ||= self.class.algorithm.new(self)
      end

      def choose!(override: nil, metadata: nil, **opts)
        return control if TrailGuide.configuration.disabled

        variant = choose_variant!(override: override, metadata: metadata, **opts)
        run_callbacks(:on_use, variant, participant, metadata)
        variant
      rescue Errno::ECONNREFUSED, Redis::BaseError, SocketError => e
        run_callbacks(:on_redis_failover, e)
        return variants.find { |var| var == override } || control if override.present?
        return control
      end

      def choose_variant!(override: nil, excluded: false, metadata: nil)
        return control if TrailGuide.configuration.disabled

        if override.present?
          variant = variants.find { |var| var == override } || control
          if running? && !is_combined?
            variant.increment_participation! if configuration.track_override
            participant.participating!(variant) if configuration.store_override
          end
          return variant
        end

        if winner?
          variant = winning_variant
          if track_winner_conversions? && running?
            variant.increment_participation! unless participant.variant == variant || !track_participation?(metadata)
            participant.exit! if participant.participating? && participant.variant != variant
            participant.participating!(variant)
          end
          return variant
        end

        return control if excluded || stopped?

        if !started? && start_manually?
          if enable_calibration?
            unless participant.variant == control
              control.increment_participation!
              parent.control.increment_participation! if is_combined?
            end

            if participant.participating? && participant.variant != control
              participant.exit!
              parent.participant.exit! if is_combined?
            end

            participant.participating!(control)
            parent.participant.participating!(parent.control) if is_combined?
          end
          return control
        end

        start! unless started? || scheduled?
        return control unless running?

        # only re-use the variant for experiments that store participation,
        # all other (i.e. content-based) experiments should re-select and
        # re-assign on enrollment
        if configuration.sticky_assignment? && participant.participating?
          variant = participant.variant
          participant.participating!(variant) if track_participation?(metadata)
          return variant
        end

        puts "allow multiple: #{TrailGuide.configuration.allow_multiple_experiments}" if TrailGuide::SpecHelper.debug == true
        puts "set to false: #{TrailGuide.configuration.allow_multiple_experiments == false}" if TrailGuide::SpecHelper.debug == true
        # puts "is participating: #{participant.participating_in_active_experiments?(TrailGuide.configuration.allow_multiple_experiments == false)}" if TrailGuide::SpecHelper.debug == true
        return control unless is_combined? || TrailGuide.configuration.allow_multiple_experiments == true || !participant.participating_in_active_experiments?(TrailGuide.configuration.allow_multiple_experiments == false || TrailGuide.configuration.allow_multiple_experiments.nil?)
        return control unless allow_participation?(metadata)

        variant = algorithm_choose!(metadata: metadata)
        if track_participation?(metadata)
          variant.increment_participation!
          participant.participating!(variant)
        end
        run_callbacks(:on_choose, variant, participant, metadata)
        variant
      end

      def algorithm_choose!(metadata: nil)
        algorithm.choose!(metadata: metadata)
      end

      def allow_participation?(metadata=nil)
        return true if callbacks[:allow_participation].empty?
        run_callbacks(:allow_participation, true, participant, metadata)
      end

      def track_participation?(metadata=nil)
        return true if callbacks[:track_participation].empty?
        run_callbacks(:track_participation, true, participant, metadata)
      end
    end
  end
end
