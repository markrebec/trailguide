module TrailGuide
  class Goal
    attr_reader :experiment, :name

    def dup(experiment)
      self.class.new(experiment, name)
    end

    def initialize(experiment, name)
      @experiment = experiment
      @name = name.to_s.underscore.to_sym
    end

    def ==(other)
      if other.is_a?(self.class)
        return name == other.name
      elsif other.is_a?(String) || other.is_a?(Symbol)
        return name == other.to_s.underscore.to_sym
      end
    end

    def ===(other)
      return false unless other.is_a?(self.class)
      return name == other.name && experiment == other.experiment
    end

    def as_json(opts={})
      {
        name: name,
      }
    end

    def to_s
      name.to_s
    end

    def storage_key
      # TODO "checkpoint/checkpoint/self.to_s"
      to_s
    end
  end
end
