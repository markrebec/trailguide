require "trail_guide/experiments/config"
require "trail_guide/experiments/participant"

module TrailGuide
  module Experiments
    class Base
      class << self
        delegate :groups, :algorithm, :control, :goals, :callbacks, :combined,
          :combined?, :allow_multiple_conversions?, :allow_multiple_goals?,
          :track_winner_conversions?, :start_manually?, :reset_manually?,
          :enable_calibration?, to: :configuration
        alias_method :funnels, :goals

        def register!
          TrailGuide.catalog.register(self)
        end

        def configuration
          @configuration ||= Experiments::Config.new(self)
        end

        def configure(*args, &block)
          configuration.configure(*args, &block)
        end

        def experiment_name
          configuration.name
        end

        def variants(include_control=true)
          if include_control
            configuration.variants
          else
            configuration.variants.select { |var| !var.control? }
          end
        end

        def combined_experiments
          combined.map { |combo| TrailGuide.catalog.find(combo) }
        end

        def run_callbacks(hook, *args)
          return unless callbacks[hook]
          return args[0] if hook == :rollout_winner
          args.unshift(self)
          callbacks[hook].each do |callback|
            if callback.respond_to?(:call)
              callback.call(*args)
            else
              send(callback, *args)
            end
          end
        end

        def start!(context=nil)
          return false if started?
          save! unless persisted?
          started = TrailGuide.redis.hset(storage_key, 'started_at', Time.now.to_i)
          run_callbacks(:on_start, context)
          started
        end

        def schedule!(start_at, stop_at=nil, context=nil)
          return false if started?
          save! unless persisted?
          scheduled = TrailGuide.redis.hset(storage_key, 'started_at', start_at.to_i)
          TrailGuide.redis.hset(storage_key, 'stopped_at', stop_at.to_i) if stop_at
          run_callbacks(:on_schedule, start_at, stop_at, context)
          scheduled
        end

        def pause!(context=nil)
          return false unless running? && configuration.can_resume?
          paused = TrailGuide.redis.hset(storage_key, 'paused_at', Time.now.to_i)
          run_callbacks(:on_pause, context)
          paused
        end

        def stop!(context=nil)
          return false unless started? && !stopped?
          stopped = TrailGuide.redis.hset(storage_key, 'stopped_at', Time.now.to_i)
          run_callbacks(:on_stop, context)
          stopped
        end

        def resume!(context=nil)
          return false unless paused? && configuration.can_resume?
          resumed = TrailGuide.redis.hdel(storage_key, 'paused_at')
          run_callbacks(:on_resume, context)
          resumed
        end

        def started_at
          started = TrailGuide.redis.hget(storage_key, 'started_at')
          return Time.at(started.to_i) if started
        end

        def paused_at
          paused = TrailGuide.redis.hget(storage_key, 'paused_at')
          return Time.at(paused.to_i) if paused
        end

        def stopped_at
          stopped = TrailGuide.redis.hget(storage_key, 'stopped_at')
          return Time.at(stopped.to_i) if stopped
        end

        def started?
          time = started_at
          time && time <= Time.now
        end

        def scheduled?
          time = started_at
          time && time > Time.now
        end

        def paused?
          time = paused_at
          time && time <= Time.now
        end

        def stopped?
          time = stopped_at
          time && time <= Time.now
        end

        def running?
          started? && !paused? && !stopped?
        end

        def calibrating?
          enable_calibration? && start_manually? && !started?
        end

        def declare_winner!(variant, context=nil)
          variant = variants.find { |var| var == variant } unless variant.is_a?(Variant)
          run_callbacks(:on_winner, variant, context)
          TrailGuide.redis.hset(storage_key, 'winner', variant.name.to_s.underscore)
        end

        def clear_winner!
          TrailGuide.redis.hdel(storage_key, 'winner')
        end

        def winner
          winner = TrailGuide.redis.hget(storage_key, 'winner')
          return variants.find { |var| var == winner } if winner
        end

        def winner?
          if combined?
            combined.all? { |combo| TrailGuide.catalog.find(combo).winner? }
          else
            TrailGuide.redis.hexists(storage_key, 'winner')
          end
        end

        def persisted?
          TrailGuide.redis.exists(storage_key)
        end

        def save!
          combined.each { |combo| TrailGuide.catalog.find(combo).save! }
          variants.each(&:save!)
          TrailGuide.redis.hsetnx(storage_key, 'name', experiment_name)
        end

        def delete!(context=nil)
          combined.each { |combo| TrailGuide.catalog.find(combo).delete! }
          variants.each(&:delete!)
          deleted = TrailGuide.redis.del(storage_key)
          run_callbacks(:on_delete, context)
          deleted
        end

        def reset!(context=nil)
          reset = (delete! && save!)
          run_callbacks(:on_reset, context)
          reset
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

        def as_json(opts={})
          # TODO add more configuration & metadata, and start actually using
          # this more
          { experiment_name => {
            configuration: {
              groups: groups,
              algorithm: algorithm.name,
              variants: variants.as_json,
              goals: goals.as_json,
              start_manually: start_manually?,
              reset_manually: reset_manually?,
              allow_multiple_conversions: allow_multiple_conversions?,
              allow_multiple_goals: allow_multiple_goals?
            },
            statistics: {
              # TODO expand on this for variants/goals
              participants: variants.sum(&:participants),
              converted: variants.sum(&:converted)
            }
          } }
        end

        def storage_key
          configuration.name
        end
      end

      attr_reader :participant
      delegate :configuration, :experiment_name, :variants, :control, :goals,
        :storage_key, :combined?, :start_manually?, :reset_manually?,
        :allow_multiple_conversions?, :allow_multiple_goals?,
        :enable_calibration?, :track_winner_conversions?, :callbacks, to: :class

      def initialize(participant)
        @participant = TrailGuide::Experiments::Participant.new(self, participant)
      end

      def algorithm
        @algorithm ||= self.class.algorithm.new(self)
      end

      def winning_variant
        run_callbacks(:rollout_winner, self.class.winner)
      end

      def choose!(override: nil, metadata: nil, **opts)
        return control if TrailGuide.configuration.disabled

        variant = choose_variant!(override: override, metadata: metadata, **opts)
        run_callbacks(:on_use, variant, metadata)
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
          if running?
            variant.increment_participation! if configuration.track_override
            participant.participating!(variant) if configuration.store_override
          end
          return variant
        end

        if winner?
          variant = winning_variant
          if track_winner_conversions? && running?
            variant.increment_participation!
            participant.participating!(variant)
          end
          return variant
        end

        return control if excluded || stopped?

        if !started? && start_manually?
          if enable_calibration?
            control.increment_participation!
            participant.participating!(control)
          end
          return control
        end

        start! unless started? || scheduled?
        return control unless running?

        if participant.participating?
          variant = participant.variant
          participant.participating!(variant)
          return variant
        end

        return control unless is_a?(TrailGuide::CombinedExperiment) || TrailGuide.configuration.allow_multiple_experiments == true || !participant.participating_in_active_experiments?(TrailGuide.configuration.allow_multiple_experiments == false)
        return control unless allow_participation?(metadata)

        variant = algorithm_choose!(metadata: metadata)
        variant_chosen!(variant, metadata: metadata)
        variant
      end

      def algorithm_choose!(metadata: nil)
        algorithm.choose!(metadata: metadata)
      end

      def variant_chosen!(variant, metadata: nil)
        variant.increment_participation!
        participant.participating!(variant)
        run_callbacks(:on_choose, variant, metadata)
      end

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

        raise InvalidGoalError, "Invalid goal checkpoint `#{checkpoint}` for `#{experiment_name}`." unless checkpoint.present? || goals.empty?
        raise InvalidGoalError, "Invalid goal checkpoint `#{checkpoint}` for `#{experiment_name}`." unless checkpoint.nil? || goals.any? { |goal| goal == checkpoint.to_s.underscore.to_sym }

        # TODO eventually allow progressing through funnel checkpoints towards goals
        if participant.converted?(checkpoint)
          return false unless allow_multiple_conversions?
        elsif participant.converted?
          return false unless allow_multiple_goals?
        end
        return false unless allow_conversion?(checkpoint, metadata)

        # TODO only reset if !reset_manually? AND they've converted all goals if
        # allow_multiple_goals? is set
        # TODO what should happen when allow_multiple_conversions? and !reset_manually?
        # TODO eventually only reset if we're at the final goal in a funnel
        participant.converted!(variant, checkpoint, reset: !reset_manually?)
        variant.increment_conversion!(checkpoint)
        run_callbacks(:on_convert, variant, checkpoint, metadata)
        variant
      rescue Errno::ECONNREFUSED, Redis::BaseError, SocketError => e
        run_callbacks(:on_redis_failover, e)
        return false
      end

      def allow_participation?(metadata=nil)
        return true if callbacks[:allow_participation].empty?
        run_callbacks(:allow_participation, metadata)
      end

      def allow_conversion?(checkpoint=nil, metadata=nil)
        return true if callbacks[:allow_conversion].empty?
        run_callbacks(:allow_conversion, checkpoint, metadata)
      end

      def run_callbacks(hook, *args)
        return unless callbacks[hook]
        if [:allow_participation, :allow_conversion, :rollout_winner].include?(hook)
          callbacks[hook].reduce(args.slice!(0,1)[0]) do |result, callback|
            if callback.respond_to?(:call)
              callback.call(self, result, *args)
            else
              send(callback, self, result, *args)
            end
          end
        else
          args.unshift(self)
          callbacks[hook].each do |callback|
            if callback.respond_to?(:call)
              callback.call(*args)
            else
              send(callback, *args)
            end
          end
        end
      end

      ### MEMOIZATOIN ###
      # This is a lot of seemingly unnecessary duplication, but it really helps
      # to cut down on the number of redis requests while still being
      # thread-safe by memoizing these methods/values here at the instance level

      def start!
        @started_at = nil
        self.class.start!
      end

      def started_at
        @started_at ||= self.class.started_at
      end

      def paused_at
        @paused_at ||= self.class.paused_at
      end

      def stopped_at
        @stopped_at ||= self.class.stopped_at
      end

      def winner
        @winner ||= self.class.winner
      end

      def scheduled?
        started_at && started_at > Time.now
      end

      def started?
        started_at && started_at <= Time.now
      end

      def paused?
        paused_at && paused_at <= Time.now
      end

      def stopped?
        stopped_at && stopped_at <= Time.now
      end

      def running?
        started? && !paused? && !stopped?
      end

      def calibrating?
        enable_calibration? && start_manually? && !started?
      end

      def winner?
        return @has_winner unless @has_winner.nil?
        @has_winner = self.class.winner?
      end

    end
  end
end
