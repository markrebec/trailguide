module TrailGuide
  class Catalog
    include Enumerable
    attr_reader :experiments

    class << self
      def experiments
        @experiments ||= new
      end

      def register(klass)
        experiments.register(klass)
      end

      def find(name)
        experiments.find(name)
      end
    end

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
        experiments.find do |exp|
          exp.experiment_name == name.to_s.underscore.to_sym ||
            exp.name == name.to_s.classify
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
