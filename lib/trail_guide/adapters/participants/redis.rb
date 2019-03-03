module TrailGuide
  module Adapters
    module Participants
      class Redis
        include Canfig::Instance

        class << self
          alias_method :configure, :new
          def new(context, **opts, &block)
            configure(&block).new(context, **opts)
          end
        end

        def initialize(&block)
          configure do |config|
            config.namespace = :participants
            config.lookup = -> (context) { context.current_user.id }
            config.expiration = nil

            yield(config) if block_given?
          end
        end

        # instance method, creates a new adapter and passes through config
        def new(context, **opts)
          Adapter.new(context, configuration, **opts)
        end

        class Adapter
          attr_reader :context, :config, :storage_key

          def initialize(context, config, key: nil)
            @context = context
            @config = config

            if key
              @storage_key = "#{config.namespace}:#{key}"
            elsif config.lookup
              if config.lookup.respond_to?(:call)
                key = config.lookup.call(context)
              else
                key = context.send(config.lookup)
              end
              @storage_key = "#{config.namespace}:#{key}"
            else
              # TODO better error
              raise ArgumentError, "You must configure a `lookup` proc"
            end
          end

          def [](field)
            TrailGuide.redis.hget(storage_key, field.to_s)
          end

          def []=(field, value)
            TrailGuide.redis.hset(storage_key, field.to_s, value)
            TrailGuide.redis.expire(storage_key, config.expiration) if config.expiration
          end

          def delete(field)
            TrailGuide.redis.hdel(storage_key, field.to_s)
          end

          def keys
            TrailGuide.redis.hkeys(storage_key)
          end

          def key?(field)
            TrailGuide.redis.hexists(storage_key, field.to_s)
          end

          def to_h
            TrailGuide.redis.hgetall(storage_key)
          end
        end
      end
    end
  end
end
