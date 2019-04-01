module TrailGuide
  module Adapters
    module Participants
      class Anonymous < Base
        class Adapter < Base::Adapter
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
