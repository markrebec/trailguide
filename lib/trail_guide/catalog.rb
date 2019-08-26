module TrailGuide
  class Catalog
    include Enumerable

    class << self
      def catalog
        @catalog ||= new
      end

      def load_experiments!(configs: [], classes: [])
        @catalog = nil

        # Load experiments from YAML configs if any exists
        [configs].flatten.each do |path|
          Dir[Rails.root.join(path)].each { |f| load_yaml_experiments(f) if ['.yml', '.yaml'].include?(File.extname(f)) }
        end

        # Load experiments from ruby configs if any exist
        [configs].flatten.each do |path|
          Dir[Rails.root.join(path)].each { |f| DSL.instance_eval(File.read(f)) if File.extname(f) == '.rb' }
        end

        # Load any experiment classes defined in the app
        [classes].flatten.each do |path|
          Dir[Rails.root.join(path)].each { |f| load f }
        end
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

          expgoals = options[:goals]
          # TODO is it worth parsing these out for complex funnels, etc.? or is
          # it better to just force use of the DSL?

          DSL.experiment(name) do |config|
            expvars.each do |expvar|
              variant *expvar
            end

            expgoals.each do |expgoal|
              goal expgoal
            end

            config.control                    = options[:control] if options[:control]
            config.groups                     = options[:groups] if options[:groups]
            config.algorithm                  = options[:algorithm] if options[:algorithm]
            config.combined                   = options[:combined] if options[:combined]
            config.reset_manually             = options[:reset_manually] if options.key?(:reset_manually)
            config.start_manually             = options[:start_manually] if options.key?(:start_manually)
            config.store_override             = options[:store_override] if options.key?(:store_override)
            config.track_override             = options[:track_override] if options.key?(:track_override)
            config.allow_multiple_conversions = options[:allow_multiple_conversions] if options.key?(:allow_multiple_conversions)
            config.allow_multiple_goals       = options[:allow_multiple_goals] if options.key?(:allow_multiple_goals)
            # TODO need to remember to update this with all the new config vars
          end
        end
      end

      def combined_experiment(combined, name)
        experiment = Class.new(TrailGuide::CombinedExperiment)
        experiment.configure combined.configuration.to_h.merge({
          name: name.to_s.underscore.to_sym,
          parent: combined,
          combined: [],
          variants: combined.configuration.variants.map { |var| var.dup(experiment) },
          goals: combined.configuration.goals.map { |goal| goal.dup(experiment) }
        })
        experiment
      end
    end

    attr_reader :experiments, :combined
    delegate :new, to: :class
    delegate :each, to: :experiments

    def initialize(experiments=[], combined=[])
      @experiments = experiments
      @combined = combined
    end

    def combined_experiment(exp, name)
      combo = @combined.find do |cex|
        cex.experiment_name == name.to_s.underscore.to_sym &&
        cex.parent.experiment_name == exp.experiment_name
      end
      return combo if combo.present?
      combo = self.class.combined_experiment(exp, name)
      @combined << combo
      combo
    end

    def groups
      experiments.map(&:groups).flatten.uniq
    end

    def all
      exploded = experiments.map do |exp|
        if exp.combined?
          exp.combined.map { |name| combined_experiment(exp, name) }
        else
          exp
        end
      end.flatten

      new(exploded, @combined)
    end

    def calibrating
      new(to_a.select(&:calibrating?), @combined)
    end

    def started
      new(to_a.select { |e| e.started? && !e.winner? }, @combined)
    end

    def scheduled
      new(to_a.select { |e| e.scheduled? && !e.winner? }, @combined)
    end

    def running
      new(to_a.select { |e| e.running? && !e.winner? }, @combined)
    end

    def paused
      new(to_a.select { |e| e.paused? && !e.winner? }, @combined)
    end

    def stopped
      new(to_a.select { |e| e.stopped? && !e.winner? }, @combined)
    end

    def ended
      new(to_a.select(&:winner?), @combined)
    end

    def unstarted
      new(to_a.select { |e| !e.started? && !e.calibrating? && !e.scheduled? && !e.winner? }, @combined)
    end

    def not_running
      new(to_a.select { |e| !e.running? }, @combined)
    end

    def by_started
      scoped = to_a.sort do |a,b|
        # TODO finish implementing specs, then implement `experiment.fresh?`, then (maybe) re-work this all
        # into an experiment spaceship operator
        if !(a.started? || a.scheduled? || a.winner?) && !(b.started? || b.scheduled? || b.winner?)
          a.experiment_name.to_s <=> b.experiment_name.to_s
        elsif !(a.started? || a.scheduled? || a.winner?)
          -1
        elsif !(b.started? || b.scheduled? || b.winner?)
          1
        else
          if a.winner? && !b.winner?
            1
          elsif !a.winner? && b.winner?
            -1
          elsif a.winner? && b.winner?
            a.experiment_name.to_s <=> b.experiment_name.to_s
          elsif a.running? && !b.running?
            -1
          elsif !a.running? && b.running?
            1
          elsif a.running? && b.running?
            if a.started_at == b.started_at
              a.experiment_name.to_s <=> b.experiment_name.to_s
            else
              a.started_at <=> b.started_at
            end
          elsif a.paused? && !b.paused?
            -1
          elsif !a.paused? && b.paused?
            1
          elsif a.paused? && b.paused?
            if a.paused_at == b.paused_at
              a.experiment_name.to_s <=> b.experiment_name.to_s
            else
              a.paused_at <=> b.paused_at
            end
          elsif a.scheduled? && !b.scheduled?
            -1
          elsif !a.scheduled? && b.scheduled?
            1
          elsif a.scheduled? && b.scheduled?
            if a.started_at == b.started_at
              a.experiment_name.to_s <=> b.experiment_name.to_s
            else
              a.started_at <=> b.started_at
            end
          elsif a.stopped? && !b.stopped?
            -1 # TODO remove unused case
          elsif !a.stopped? && b.stopped?
            1 # TODO remove unused case
          elsif a.stopped? && b.stopped?
            if a.stopped_at == b.stopped_at
              a.experiment_name.to_s <=> b.experiment_name.to_s
            else
              a.stopped_at <=> b.stopped_at
            end
          else
            a.experiment_name.to_s <=> b.experiment_name.to_s
          end
        end
      end

      new(scoped, @combined)
    end

    def find(name)
      if name.is_a?(Class)
        experiments.find { |exp| exp == name }
      else
        experiment = experiments.find do |exp|
          exp.experiment_name == name.to_s.underscore.to_sym ||
            exp.groups.include?(name.to_s.underscore.to_sym) ||
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
        selected = experiments.select { |exp| exp == name }
      else
        # TODO we can be more efficient than mapping twice here
        selected = experiments.select do |exp|
          exp.experiment_name == name.to_s.underscore.to_sym ||
            exp.groups.include?(name.to_s.underscore.to_sym) ||
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

      new(selected, @combined)
    end

    def register(klass)
      experiments << klass unless experiments.any? { |exp| exp == klass }
      klass
    end

    def deregister(key, remove_const=false)
      klass = find(key)
      return unless klass.present?
      experiments.delete(klass)
      return klass unless remove_const && klass.name.present?
      Object.send(:remove_const, :"#{klass.name}")
      return key
    end

    def export
      map do |exp|
        if exp.combined?
          [exp.as_json].concat(exp.combined_experiments.map(&:as_json))
        else
          exp.as_json
        end
      end.flatten.reduce({}) { |red,exp| red.merge!(exp) }
    end

    def import(state)
      state.each do |exp,est|
        experiment = find(exp)
        next unless experiment.present?

        experiment.reset!
        TrailGuide.redis.hsetnx(experiment.storage_key, 'name', experiment.experiment_name)
        TrailGuide.redis.hset(experiment.storage_key, 'started_at', DateTime.parse(est['started_at']).to_i) if est['started_at'].present?
        TrailGuide.redis.hset(experiment.storage_key, 'paused_at', DateTime.parse(est['paused_at']).to_i) if est['paused_at'].present?
        TrailGuide.redis.hset(experiment.storage_key, 'stopped_at', DateTime.parse(est['stopped_at']).to_i) if est['stopped_at'].present?
        TrailGuide.redis.hset(experiment.storage_key, 'winner', est['winner']) if est['winner'].present?

        est['variants'].each do |var,vst|
          variant = experiment.variants.find { |v| v == var }
          next unless variant.present?

          TrailGuide.redis.hincrby(variant.storage_key, 'participants', vst['participants'].to_i) if vst['participants'].to_i > 0
          if vst['converted'].is_a?(Hash)
            vst['converted'].each do |goal,gct|
              TrailGuide.redis.hincrby(variant.storage_key, goal, gct.to_i) if gct.to_i > 0
            end
          else
            TrailGuide.redis.hincrby(variant.storage_key, 'converted', vst['converted'].to_i) if vst['converted'].to_i > 0
          end
        end
      end
    end

    def missing
      TrailGuide.redis.keys.select do |key|
        exp = key.split(':').first
        find(exp).nil?
      end
    end

    def orphaned(key, trace)
      added = TrailGuide.redis.sadd("orphans:#{key}", trace)
      TrailGuide.redis.expire("orphans:#{key}", 15.minutes.seconds)
      added
    rescue Errno::ECONNREFUSED, Redis::BaseError, SocketError => e
      false
    end

    def orphans
      TrailGuide.redis.keys("orphans:*").reduce({}) do |h,key|
        h.merge({ key.split(':').last => TrailGuide.redis.smembers(key) })
      end
    rescue Errno::ECONNREFUSED, Redis::BaseError, SocketError => e
      {}
    end

    def adopted(key)
      TrailGuide.redis.del("orphans:#{key}")
    rescue Errno::ECONNREFUSED, Redis::BaseError, SocketError => e
      false
    end

    def method_missing(meth, *args, &block)
      return experiments.send(meth, *args, &block) if experiments.respond_to?(meth, true)
      super
    end

    def respond_to_missing?(meth, include_private=false)
      experiments.respond_to?(meth, include_private)
    end

    class DSL
      def self.experiment(name, **opts, &block)
        klass = opts.delete(:class) || TrailGuide::Experiment
        Class.new(klass) do
          configure opts.merge({name: name}), &block
          register!
        end
      end
    end
  end

  # TrailGuide.catalog
  def self.catalog
    TrailGuide::Catalog.catalog
  end
end
