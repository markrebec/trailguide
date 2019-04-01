module TrailGuide
  module Adapters
    module Participants
      class Base
        include Canfig::Instance

        class << self
          alias_method :configure, :new
          def new(context, &block)
            configure(&block).new(context)
          end
        end

        def initialize(&block)
          configure(&block) if block_given?
        end

        def new(context)
          self.class::Adapter.new(context, configuration)
        end

        class Adapter
          attr_reader :context, :config
          alias_method :configuration, :config

          def initialize(context, config)
            @context = context
            @config = config
          end

          def [](key)
          end

          def []=(key, value)
          end

          def delete(key)
          end

          def destroy!
          end

          def keys
          end

          def key?(key)
          end

          def to_h
          end
        end
      end
    end
  end
end
