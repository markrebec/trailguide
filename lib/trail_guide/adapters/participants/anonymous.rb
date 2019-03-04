module TrailGuide
  module Adapters
    module Participants
      class Anonymous
        include Canfig::Instance

        class << self
          alias_method :configure, :new
          def new(context, &block)
            configure(&block).new(context)
          end
        end

        def initialize(&block)
          configure do |config|
            yield(config) if block_given?
          end
        end

        # instance method, creates a new adapter and passes through config
        def new(context)
          Adapter.new(context, configuration)
        end

        class Adapter
          attr_reader :context, :config

          def initialize(context, config)
            @context = context
            @config = config
          end

          def [](key)
            hash[key]
          end

          def []=(key, value)
            hash[key] = value
          end

          def delete(key)
            hash.delete(key)
          end

          def destroy!
            @hash = nil
          end

          def keys
            hash.keys
          end

          def key?(key)
            hash.key?(key)
          end

          def to_h
            hash.to_h
          end

          private

          def hash
            @hash ||= {}
          end
        end
      end
    end
  end
end
