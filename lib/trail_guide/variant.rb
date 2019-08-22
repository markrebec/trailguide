module TrailGuide
  class Variant
    attr_reader :experiment, :name, :metadata, :weight

    def dup(experiment)
      self.class.new(experiment, name, metadata: metadata, weight: weight, control: control?)
    end

    def initialize(experiment, name, metadata: {}, weight: 1, control: false)
      @experiment = experiment
      @name = name.to_s.underscore.to_sym
      @metadata = metadata
      @weight = weight
      @control = control
    end

    def adapter
      @adapter ||= TrailGuide::Adapters::Variants::Redis.new(self)
    end

    def ==(other)
      if other.is_a?(self.class)
        # TODO eventually remove the experiment requirement here once we start
        # taking advantage of === below
        return name == other.name && experiment == other.experiment
      elsif other.is_a?(String) || other.is_a?(Symbol)
        return name == other.to_s.underscore.to_sym
      end
    end

    def ===(other)
      return false unless other.is_a?(self.class)
      return name == other.name && experiment == other.experiment
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
      adapter.persisted?
    end

    def save!
      adapter.setnx(:name, name)
    end

    def delete!
      adapter.destroy
    end

    def reset!
      delete!
      save!
    end

    def participants
      (adapter.get(:participants) || 0).to_i
    end

    def converted(checkpoint=nil)
      if experiment.goals.empty?
        raise InvalidGoalError, "You provided the checkpoint `#{checkpoint}` but the experiment `#{experiment.experiment_name}` does not have any goals defined." unless checkpoint.nil?
        (adapter.get(:converted) || 0).to_i
      elsif !checkpoint.nil?
        goal = experiment.goals.find { |g| g == checkpoint }
        raise InvalidGoalError, "Invalid goal checkpoint `#{checkpoint}` for experiment `#{experiment.experiment_name}`." if goal.nil?
        (adapter.get(goal.name) || 0).to_i
      else
        experiment.goals.sum do |goal|
          (adapter.get(goal.name) || 0).to_i
        end
      end
    end

    def unconverted
      participants - converted
    end

    def measure(goal=nil, against=nil)
      superset = against ? converted(against) : participants
      converts = converted(goal)
      return 0 if superset.zero? || converts.zero?
      converts.to_f / superset.to_f
    end

    def increment_participation!
      adapter.increment(:participants)
    end

    def increment_conversion!(checkpoint=nil)
      if checkpoint.nil?
        checkpoint = :converted
      else
        checkpoint = experiment.goals.find { |g| g == checkpoint }.name
      end
      adapter.increment(checkpoint)
    end

    # export the variant state (not config) as json
    def as_json(opts={})
      if experiment.goals.empty?
        conversions = converted
      else
        conversions = experiment.goals.map { |g| [g.name, converted(g)] }.to_h
      end

      { name => { participants: participants,
                  converted: conversions } }
    end

    def to_s
      name.to_s
    end

    def storage_key
      "#{experiment.experiment_name}:#{name}"
    end
  end
end
