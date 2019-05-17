module TrailGuide
  module Metrics
    # represents a checkpoint in a funnel
    # TODO this is mostly a placeholder for now
    class Checkpoint < Goal
      attr_reader :experiment, :name

      def dup(experiment)
        self.class.new(experiment, name)
      end

      def initialize(experiment, name, checkpoints=[])
        @experiment = experiment
        @name = name.to_s.underscore.to_sym
      end

      def as_json(opts={})
        {
          name: name,
        }
      end
    end
  end
end
