module TrailGuide
  module Experiments
    module Lifecycle

      def self.included(base)
        base.send :extend, ClassMethods
      end

      module ClassMethods
        def start!(context=nil)
          return false if started?
          save! unless persisted?
          started = adapter.set(:started_at, Time.now.to_i)
          run_callbacks(:on_start, context)
          started
        end

        def schedule!(start_at, stop_at=nil, context=nil)
          return false if started?
          save! unless persisted?
          scheduled = adapter.set(:started_at, start_at.to_i)
          adapter.set(:stopped_at, stop_at.to_i) if stop_at
          run_callbacks(:on_schedule, start_at, stop_at, context)
          scheduled
        end

        def pause!(context=nil)
          return false unless running? && configuration.can_resume?
          paused = adapter.set(:paused_at, Time.now.to_i)
          run_callbacks(:on_pause, context)
          paused
        end

        def stop!(context=nil)
          return false unless started? && !stopped?
          stopped = adapter.set(:stopped_at, Time.now.to_i)
          run_callbacks(:on_stop, context)
          stopped
        end

        def resume!(context=nil)
          return false unless paused? && configuration.can_resume?
          resumed = adapter.delete(:paused_at)
          run_callbacks(:on_resume, context)
          !!resumed
        end

        def started_at
          started = adapter.get(:started_at)
          return Time.at(started.to_i) if started
        end

        def paused_at
          paused = adapter.get(:paused_at)
          return Time.at(paused.to_i) if paused
        end

        def stopped_at
          stopped = adapter.get(:stopped_at)
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

        def fresh?
          !started? && !scheduled? && !winner?
        end

        def declare_winner!(variant, context=nil)
          variant = variants.find { |var| var == variant } unless variant.is_a?(Variant)
          return false unless variant.present? && variant.experiment == self
          run_callbacks(:on_winner, variant, context)
          adapter.set(:winner, variant.name)
          variant
        end

        def clear_winner!
          adapter.delete(:winner)
        end

        def winner?
          if combined?
            combined.all? { |combo| TrailGuide.catalog.find(combo).winner? }
          else
            adapter.exists?(:winner)
          end
        end

        def run_callbacks(hook, *args)
          return unless callbacks[hook]
          return args[0] if hook == :rollout_winner # TODO do we need to account for this case here at the class level?
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

      def run_callbacks(hook, *args)
        return unless callbacks[hook]
        if [:allow_participation, :allow_conversion, :track_participation, :rollout_winner].include?(hook)
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
