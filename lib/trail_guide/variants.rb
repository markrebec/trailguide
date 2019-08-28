module TrailGuide
  class Variants
    attr_reader :variants
    alias_method :to_a, :variants
    delegate :each, :map, to: :variants

    def initialize(*vars)
      @variants = vars.flatten
    end

    def dup(experiment)
      self.class.new(variants.map { |var| var.dup(experiment) })
    end

    def control
      variants.find { |var| var.control? }
    end

    def method_missing(meth, *args, &block)
      variant = variants.find { |var| var == meth }
      return variant if variant.present?

      if variants.respond_to?(meth, true)
        result = variants.send(meth, *args, &block)
        if result.is_a?(Array)
          return self.class.new(result)
        else
          return result
        end
      end

      super
    end

    def respond_to_missing?(meth, include_private=false)
      variants.find { |var| var == meth }.present? || variants.respond_to?(meth, include_private)
    end
  end
end
