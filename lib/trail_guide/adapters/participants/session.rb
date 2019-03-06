module TrailGuide
  module Adapters
    module Participants
      class Session
        include Canfig::Instance

        class << self
          alias_method :configure, :new
          def new(context, &block)
            configure(&block).new(context)
          end
        end

        def initialize(&block)
          configure do |config|
            config.key = :trailguide

            yield(config) if block_given?
          end
        end

        # instance method, creates a new adapter and passes through config
        def new(context)
          raise UnsupportedContextError, "Your current context (#{context}) does not support sessions" unless context.respond_to?(:session, true)
          Adapter.new(context, configuration)
        end

        class Adapter
          attr_reader :context, :config

          def initialize(context, config)
            @context = context
            @config = config
          end

          def [](key)
            session[key]
          end

          def []=(key, value)
            session[key] = value
          end

          def delete(key)
            session.delete(key)
          end

          def destroy!
            context.send(:session).delete(config.key)
          end

          def keys
            session.keys
          end

          def key?(key)
            session.key?(key)
          end

          def to_h
            session.to_h
          end

          private

          def session
            context.send(:session)[config.key] ||= {}
          end
        end
      end
    end
  end
end
