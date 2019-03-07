module TrailGuide
  class Variant
    attr_reader :experiment, :name, :metadata, :weight

    def initialize(experiment, name, metadata: {}, weight: 1, control: false)
      @experiment = experiment
      @name = name.to_s.underscore.to_sym
      @metadata = metadata
      @weight = weight
      @control = control
    end

    def ==(other)
      if other.is_a?(self.class)
        return name == other.name && experiment == other.experiment
      elsif other.is_a?(String) || other.is_a?(Symbol)
        return name == other.to_s.underscore.to_sym
      end
    end

    # TODO maybe track the control on the experiment itself, rather than as a
    # flag on the variants like this?

    # mark this variant as the control
    def control!
      @control = true
    end

    # check if this variant is the control
    def control?
      !!@control
    end

    # unmark this variant as the control
    def variant!
      @control = false
    end

    def persisted?
      TrailGuide.redis.exists(storage_key)
    end

    def save!
      TrailGuide.redis.hsetnx(storage_key, 'name', name)
    end

    def delete!
      TrailGuide.redis.del(storage_key)
    end

    def reset!
      delete! && save!
    end

    def participants
      (TrailGuide.redis.hget(storage_key, 'participants') || 0).to_i
    end

    def converted(checkpoint=nil)
      if experiment.goals.empty?
        raise InvalidGoalError, "You provided the checkpoint `#{checkpoint}` but the experiment `#{experiment.experiment_name}` does not have any goals defined." unless checkpoint.nil?
        (TrailGuide.redis.hget(storage_key, 'converted') || 0).to_i
      elsif !checkpoint.nil?
        raise InvalidGoalError, "Invalid goal checkpoint `#{checkpoint}` for experiment `#{experiment.experiment_name}`." unless experiment.goals.any? { |goal| goal == checkpoint.to_s.underscore.to_sym }
        (TrailGuide.redis.hget(storage_key, checkpoint.to_s.underscore) || 0).to_i
      else
        experiment.goals.sum do |checkpoint|
          (TrailGuide.redis.hget(storage_key, checkpoint.to_s.underscore) || 0).to_i
        end
      end
    end

    def unconverted
      participants - converted
    end

    def increment_participation!
      TrailGuide.redis.hincrby(storage_key, 'participants', 1)
    end

    def increment_conversion!(checkpoint=nil)
      checkpoint ||= :converted
      TrailGuide.redis.hincrby(storage_key, checkpoint.to_s.underscore, 1)
    end

    def as_json(opts={})
      {
        name: name,
        control: control?,
        weight: weight,
        metadata: metadata.as_json,
      }
    end

    def to_s
      name.to_s
    end

    def storage_key
      "#{experiment.experiment_name}:#{name}"
    end
  end
end
