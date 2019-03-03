module TrailGuide
  class Experiment
    class << self
      def inherited(child)
        # TODO allow inheriting algo, variants, goals, metrics, etc.
        TrailGuide::Catalog.register(child)
      end

      def experiment_name(name=nil)
        @experiment_name = name.to_s.underscore.to_sym unless name.nil?
        @experiment_name || self.name.try(:underscore).try(:to_sym)
      end

      def algorithm(algo=nil)
        @algorithm = algo unless algo.nil?
        @algorithm ||= TrailGuide.configuration.algorithm
      end

      def variant(name, metadata: {}, weight: 1, control: false)
        raise ArgumentError, "The variant #{name} already exists in experiment #{experiment_name}" if variants.any? { |var| var == name }
        control = true if variants.empty?
        variant = Variant.new(self, name, metadata: metadata, weight: weight, control: control)
        variants << variant
        variant
      end

      def variants(include_control=true)
        @variants ||= []
        if include_control
          @variants
        else
          @variants.select { |var| !var.control? }
        end
      end

      def control(name=nil)
        return variants.find { |var| var.control? } || variants.first if name.nil?

        variants.each(&:variant!)
        var_idx = variants.index { |var| var == name }

        if var_idx.nil?
          variant = Variant.new(self, name, control: true)
        else
          variant = variants.slice!(var_idx, 1)[0]
          variant.control!
        end

        variants.unshift(variant)
        return variant
      end

      def checkpoint(name)
        checkpoints << name.to_s.underscore.to_sym
      end
      alias_method :goal, :checkpoint

      def checkpoints
        @checkpoints ||= []
      end
      alias_method :goals, :checkpoints

      def metric(key=nil)
        @metric = key.to_s.underscore.to_sym unless key.nil?
        @metric ||= experiment_name
      end

      def start!
        return false if started?
        save! unless persisted?
        TrailGuide.redis.hset(storage_key, 'started_at', Time.now.to_i)
      end

      def stop!
        return false unless started?
        TrailGuide.redis.hdel(storage_key, 'started_at')
      end

      def started_at
        started = TrailGuide.redis.hget(storage_key, 'started_at')
        return Time.at(started.to_i) if started
      end

      def started?
        !!started_at
      end

      def declare_winner!(variant)
        variant = variant.name if variant.is_a?(Variant)
        TrailGuide.redis.hset(storage_key, 'winner', variant.to_s.underscore)
      end

      def winner
        winner = TrailGuide.redis.hget(storage_key, 'winner')
        return variants.find { |var| var == winner } if winner
      end

      def winner?
        !!winner
      end

      def persisted?
        TrailGuide.redis.exists(storage_key)
      end

      def save!
        variants.each(&:save!)
        TrailGuide.redis.hsetnx(storage_key, 'name', experiment_name)
      end

      def delete!
        variants.each(&:delete!)
        TrailGuide.redis.del(storage_key)
        # TODO also clear out stats, etc.
      end

      def reset!
        delete! && save!
      end

      def as_json(opts={})
        {
          experiment_name: experiment_name,
          algorithm: algorithm,
          variants: variants.as_json
        }
      end

      def storage_key
        experiment_name
      end
    end

    attr_reader :participant
    delegate :experiment_name, :variants, :control, :checkpoints, :storage_key,
      :started?, :started_at, :winner?, :winner, to: :class

    def initialize(participant)
      @participant = participant
    end

    def algorithm
      @algorithm ||= self.class.algorithm.new(self)
    end

    def excluded?
      false # TODO
    end

    def choose!(override: nil)
      # TODO return override if provided (should be passed through from context helpers)
      return control if TrailGuide.configuration.disabled
      return winner if winner?
      return control if excluded?
      return variants.find { |var| var == participant[storage_key] } if participating?
      return control if !started?

      chosen = algorithm.choose!
      participant[storage_key] = chosen.name
      participant[timestamp_key] = Time.now.to_i
      chosen.increment_participation!
      chosen
    end

    def checkpoint!(checkpoint=nil)
      # TODO either require nested hash format for nested checkpoints, or require
      # the participant has completed the checkpoint
      return false unless participating?
      raise ArgumentError, "You must provide a valid checkpoint for #{experiment_name}" unless checkpoint.present? || checkpoints.empty?
      raise ArgumentError, "Unknown checkpoint: #{checkpoint}" unless checkpoint.nil? || checkpoints.any? { |ckp| ckp == checkpoint.to_s.underscore.to_sym }

      variant = variants.find { |var| var == participant[storage_key] }
      participant[checkpoint_key(checkpoint)] = Time.now.to_i
      variant.increment_conversion!(checkpoint)
    end

    private

    def participating?
      return false unless started?
      return false unless participant.key?(storage_key) && participant.key?(timestamp_key)

      # make sure if they have a previously selected variant, that it came from
      # the current test run (i.e. after an resets or restarts)
      chosen_at = Time.at(participant[timestamp_key].to_i) 
      chosen_at >= started_at
    end

    def checkpoint_key(checkpoint=nil)
      checkpoint ||= :converted
      "#{storage_key}:#{checkpoint.to_s.underscore}"
    end

    def timestamp_key
      "#{storage_key}:chosen_at"
    end
  end
end
