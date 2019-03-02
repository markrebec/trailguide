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
  end
end
