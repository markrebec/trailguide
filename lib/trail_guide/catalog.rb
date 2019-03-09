module TrailGuide
  class Catalog
    class DSL
      def self.experiment(name, &block)
        Class.new(TrailGuide::Experiment) do
          configure name: name
          configure &block
        end
      end
    end

    include Enumerable

    class << self
      def catalog
        @catalog ||= new
      end

      def load_experiments!
        @catalog = nil

        # Load experiments from YAML configs if any exists
        load_yaml_experiments(Rails.root.join("config/experiments.yml"))
        Dir[Rails.root.join("config/experiments/**/*.yml")].each { |f| load_yaml_experiments(f) }

        # Load experiments from ruby configs if any exist
        DSL.instance_eval(File.read(Rails.root.join("config/experiments.rb"))) if File.exists?(Rails.root.join("config/experiments.rb"))
        Dir[Rails.root.join("config/experiments/**/*.rb")].each { |f| DSL.instance_eval(File.read(f)) }

        # Load any experiment classes defined in the app
        Dir[Rails.root.join("app/experiments/**/*.rb")].each { |f| load f }
      end

      def load_yaml_experiments(file)
        experiments = (YAML.load_file(file) || {} rescue {})
          .symbolize_keys.map { |k,v| [k, v.symbolize_keys] }.to_h

        experiments.each do |name, options|
          expvars = options[:variants].map do |var|
            if var.is_a?(Array)
              [var[0], var[1].symbolize_keys]
            else
              [var]
            end
          end

          DSL.experiment(name) do |config|
            expvars.each do |expvar|
              variant *expvar
            end
            # TODO also map goals once they're real classes
            config.control                    = options[:control] if options[:control]
            config.metric                     = options[:metric] if options[:metric]
            config.algorithm                  = options[:algorithm] if options[:algorithm]
            config.goals                      = options[:goals] if options[:goals]
            config.combined                   = options[:combined] if options[:combined]
            config.reset_manually             = options[:reset_manually] if options.key?(:reset_manually)
            config.start_manually             = options[:start_manually] if options.key?(:start_manually)
            config.store_override             = options[:store_override] if options.key?(:store_override)
            config.track_override             = options[:track_override] if options.key?(:track_override)
            config.allow_multiple_conversions = options[:allow_multiple_conversions] if options.key?(:allow_multiple_conversions)
            config.allow_multiple_goals       = options[:allow_multiple_goals] if options.key?(:allow_multiple_goals)
          end
        end
      end

      def combined_experiment(combined, name)
        experiment = Class.new(TrailGuide::CombinedExperiment)
        experiment.configure combined.configuration.to_h.merge({
          name: name.to_s.underscore.to_sym,
          parent: combined,
          combined: [],
          variants: combined.configuration.variants.map { |var| var.dup(experiment) }
          # TODO also map goals once they're separate classes
        })
        experiment
      end
    end

    delegate :combined_experiment, to: :class
    attr_reader :experiments

    def initialize(experiments=[])
      @experiments = experiments
    end

    def each(&block)
      experiments.each(&block)
    end

    def all
      experiments.map do |exp|
        if exp.combined?
          exp.combined.map { |name| combined_experiment(exp, name) }
        else
          exp
        end
      end.flatten
    end

    def started
      to_a.select(&:started?)
    end

    def running
      to_a.select(&:running?)
    end

    def stopped
      to_a.select(&:stopped?)
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

        return combined_experiment(combined, name)
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
            combined_experiment(exp, name)
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
