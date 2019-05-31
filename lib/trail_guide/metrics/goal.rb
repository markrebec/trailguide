module TrailGuide
  module Metrics
    # represents a simple conversion goal
    class Goal
      attr_reader :experiment, :name

      delegate :allow_multiple_conversions?, :callbacks, to: :configuration

      def dup(experiment)
        self.class.new(experiment, name, **configuration.to_h.map { |k,v| [k, v.try(:dup)] }.to_h)
      end

      def configuration
        @configuration ||= Metrics::Config.new(self)
      end

      def configure(*args, &block)
        configuration.configure(*args, &block)
      end

      def initialize(experiment, name, **config, &block)
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

      def allow_conversion?(trial, variant, metadata=nil)
        return true if callbacks[:allow_conversion].empty?
        run_callbacks(:allow_conversion, trial, true, variant, trial.participant, metadata)
      end

      def run_callbacks(hook, trial, *args)
        return unless callbacks[hook]
        if [:allow_conversion].include?(hook)
          callbacks[hook].reduce(args.slice!(0,1)[0]) do |result, callback|
            if callback.respond_to?(:call)
              callback.call(trial, result, self, *args)
            else
              trial.send(callback, trial, result, self, *args)
            end
          end
        else
          args.unshift(self)
          args.unshift(trial)
          callbacks[hook].each do |callback|
            if callback.respond_to?(:call)
              callback.call(*args)
            else
              trial.send(callback, *args)
            end
          end
        end
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
