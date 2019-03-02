module TrailGuide
  class Experiment
    class << self
      def inherited(child)
        # TODO allow inheriting algo, variants, goals, metrics, etc.
        TrailGuide::Catalog.register(child)
      end

      def experiment_name(name=nil)
        @experiment_name = name.to_s.underscore.to_sym unless name.nil?
        @experiment_name || self.name.try(:underscore).try(:to_sym)
      end

      def algorithm(algo=nil)
        @algorithm = algo unless algo.nil?
        @algorithm # TODO set a default algorithm? or handle it w/ config?
      end

      def variant(name, metadata: {}, control: false)
        raise ArgumentError, "The variant #{name} already exists in experiment #{experiment_name}" if variants.any? { |var| var == name }
        control = true if variants.empty?
        variant = Variant.new(self, name, metadata: metadata, control: control)
        variants << variant
        variant
      end

      def variants(include_control=true)
        @variants ||= []
        if include_control
          @variants
        else
          @variants.select { |var| !var.control? }
        end
      end

      def control(name=nil)
        return variants.find { |var| var.control? } || variants.first if name.nil?

        variants.each(&:variant!)
        var_idx = variants.index { |var| var == name }

        if var_idx.nil?
          variant = Variant.new(self, name, control: true)
        else
          variant = variants.slice!(var_idx, 1)[0]
          variant.control!
        end

        variants.unshift(variant)
        return variant
      end
    end
  end
end
