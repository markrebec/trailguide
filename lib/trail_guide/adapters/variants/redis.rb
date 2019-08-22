module TrailGuide
  module Adapters
    module Variants
      class Redis
        attr_reader :variant
        delegate :storage_key, to: :variant

        def initialize(variant, redis: nil)
          @variant = variant
          @redis = redis
        end

        def redis
          @redis ||= TrailGuide.redis
        end

        def get(attr)
          redis.hget(storage_key, attr.to_s)
        end

        def set(attr, val)
          redis.hset(storage_key, attr.to_s, val.to_s)
        end

        def setnx(attr, val)
          redis.hsetnx(storage_key, attr.to_s, val.to_s)
        end

        def increment(attr, cnt=1)
          redis.hincrby(storage_key, attr.to_s, cnt)
        end

        def delete(attr)
          redis.hdel(storage_key, attr.to_s)
        end

        def exists?(attr)
          redis.hexists(storage_key, attr.to_s)
        end

        def persisted?
          redis.exists(storage_key)
        end

        def destroy
          redis.del(storage_key)
        end
      end
    end
  end
end
