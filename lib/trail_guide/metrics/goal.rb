module TrailGuide
  module Metrics
    # represents a simple conversion goal
    class Goal
      attr_reader :experiment, :name

      def dup(experiment)
        self.class.new(experiment, name, config: configuration.map { |k,v| [k, v.try(:dup)] }.to_h)
      end

      def configuration
        @configuration ||= Metrics::Config.new(self)
      end

      def configure(*args, &block)
        configuration.configure(*args, &block)
      end

      def initialize(experiment, name, config: {}, &block)
        @experiment = experiment
        @name = name.to_s.underscore.to_sym
        configure(**config, &block)
      end

      def ==(other)
        if other.is_a?(self.class)
          return name == other.name
        elsif other.is_a?(String) || other.is_a?(Symbol)
          other = other.to_s.underscore
          return name == other.to_sym || to_s == other
        elsif other.is_a?(Array)
          return to_s == other.flatten.map { |o| o.to_s.underscore }.join('/')
        elsif other.is_a?(Hash)
          # TODO "flatten" it out and compare it to_s
          return false
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
        "#{experiment.experiment_name}:#{name}"
      end
    end
  end
end
