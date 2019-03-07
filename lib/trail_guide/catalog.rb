module TrailGuide
  class Catalog
    include Enumerable

    class << self
      def catalog
        @catalog ||= new
      end

      def register(klass)
        catalog.register(klass)
      end

      def find(name)
        catalog.find(name)
      end

      def select(name)
        catalog.select(name)
      end

      def combined_experiment(combined, name)
        experiment = Class.new(TrailGuide::CombinedExperiment)
        experiment.configure combined.configuration.to_h.merge({
          name: name.to_s.underscore.to_sym,
          parent: combined,
          combined: [],
          variants: combined.configuration.variants.map { |var| Variant.new(experiment, var.name, metadata: var.metadata, weight: var.weight, control: var.control?) },
          # TODO also map goals
        })
        experiment
      end
    end

    attr_reader :experiments

    def initialize(experiments=[])
      @experiments = experiments
    end

    def each(&block)
      experiments.each(&block)
    end

    def find(name)
      if name.is_a?(Class)
        experiments.find { |exp| exp == name }
      else
        experiment = experiments.find do |exp|
          exp.experiment_name == name.to_s.underscore.to_sym ||
            exp.metric == name.to_s.underscore.to_sym ||
            exp.name == name.to_s.classify
        end
        return experiment if experiment.present?

        combined = experiments.find do |exp|
          next unless exp.combined?
          exp.combined.any? { |combo| combo.to_s.underscore.to_sym == name.to_s.underscore.to_sym }
        end
        return nil unless combined.present?

        return self.class.combined_experiment(combined, name)
      end
    end

    def select(name)
      if name.is_a?(Class)
        experiments.select { |exp| exp == name }
      else
        # TODO we can be more efficient than mapping twice here
        experiments.select do |exp|
          exp.experiment_name == name.to_s.underscore.to_sym ||
            exp.metric == name.to_s.underscore.to_sym ||
            exp.name == name.to_s.classify ||
            (exp.combined? && exp.combined.any? { |combo| combo.to_s.underscore.to_sym == name.to_s.underscore.to_sym })
        end.map do |exp|
          if exp.combined? && exp.combined.any? { |combo| combo.to_s.underscore.to_sym == name.to_s.underscore.to_sym }
            self.class.combined_experiment(exp, name)
          else
            exp
          end
        end
      end
    end

    def register(klass)
      experiments << klass unless experiments.any? { |exp| exp == klass }
      klass
    end

    def method_missing(meth, *args, &block)
      return experiments.send(meth, *args, &block) if experiments.respond_to?(meth, true)
      super
    end

    def respond_to_missing?(meth, include_private=false)
      experiments.respond_to?(meth, include_private)
    end
  end
end
