module TrailGuide
  class Engine < ::Rails::Engine
    isolate_namespace TrailGuide

    config.generators do |g|
      g.test_framework = :rspec
    end

    initializer "trailguide" do |app|
      TrailGuide::Engine.load_experiments
      ActionController::Base.send :include, TrailGuide::Helper
      ActionController::Base.helper TrailGuide::Helper
    end

    def self.load_experiments
      # Load experiments from YAML configs if any exists
      load_yaml_experiments(Rails.root.join("config/experiments.yml"))
      Dir[Rails.root.join("config/experiments/**/*.yml")].each { |f| load_yaml_experiments(f) }

      # Load experiments from ruby configs if any exist
      DSL.instance_eval(File.read(Rails.root.join("config/experiments.rb"))) if File.exists?(Rails.root.join("config/experiments.rb"))
      Dir[Rails.root.join("config/experiments/**/*.rb")].each { |f| DSL.instance_eval(File.read(f)) }

      # Load any experiment classes defined in the app
      Dir[Rails.root.join("app/experiments/**/*.rb")].each { |f| load f }
    end

    def self.load_yaml_experiments(file)
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
          config.control                    = options[:control] if options[:control]
          config.metric                     = options[:metric] if options[:metric]
          config.algorithm                  = options[:algorithm] if options[:algorithm]
          config.goals                      = options[:goals] if options[:goals]
          config.reset_manually             = options[:reset_manually] if options.key?(:reset_manually)
          config.start_manually             = options[:start_manually] if options.key?(:start_manually)
          config.store_override             = options[:store_override] if options.key?(:store_override)
          config.track_override             = options[:track_override] if options.key?(:track_override)
          config.allow_multiple_conversions = options[:allow_multiple_conversions] if options.key?(:allow_multiple_conversions)
          config.allow_multiple_goals       = options[:allow_multiple_goals] if options.key?(:allow_multiple_goals)
        end
      end
    end

    class DSL
      def self.experiment(name, &block)
        Class.new(TrailGuide::Experiment) do
          configure do |config|
            config.name = name
          end
          configure &block
        end
      end
    end
  end
end
