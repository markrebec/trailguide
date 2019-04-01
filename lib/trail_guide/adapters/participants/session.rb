module TrailGuide
  module Adapters
    module Participants
      class Session < Base

        def initialize(&block)
          configure do |config|
            config.key = :trailguide

            yield(config) if block_given?
          end
        end

        class Adapter < Base::Adapter

          def initialize(context, config)
            raise UnsupportedContextError, "Your current context (#{context}) does not support sessions" unless context.respond_to?(:session, true)
            super
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
