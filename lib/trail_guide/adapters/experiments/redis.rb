module TrailGuide
  module Adapters
    module Experiments
      class Redis
        attr_reader :experiment
        delegate :storage_key, to: :experiment

        def initialize(experiment, redis: nil)
          @experiment = experiment
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
          val.to_s
        end

        def setnx(attr, val)
          val.to_s if redis.hsetnx(storage_key, attr.to_s, val.to_s)
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
