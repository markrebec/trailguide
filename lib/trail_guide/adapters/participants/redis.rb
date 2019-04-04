module TrailGuide
  module Adapters
    module Participants
      class Redis < Base

        def initialize(&block)
          configure do |config|
            config.namespace = :participants
            config.lookup = -> (context) {
              context.try(:trailguide_user).try(:id) ||
                context.try(:current_user).try(:id)
            }
            config.expiration = nil

            yield(config) if block_given?
          end
        end

        class Adapter < Base::Adapter
          attr_reader :storage_key

          def initialize(context, config, key: nil)
            super(context, config)

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
              raise ArgumentError, "You must configure a `lookup` proc to use the redis adapter."
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

          def destroy!
            TrailGuide.redis.del(storage_key)
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
