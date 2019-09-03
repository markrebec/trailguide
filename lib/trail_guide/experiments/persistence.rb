module TrailGuide
  module Experiments
    module Persistence

      def self.included(base)
        base.send :extend, ClassMethods
      end

      module ClassMethods
        def adapter
          @adapter ||= TrailGuide::Adapters::Experiments::Redis.new(self)
        end

        def persisted?
          adapter.persisted?
        end

        def save!
          combined_experiments.each(&:save!)
          variants.each(&:save!)
          adapter.setnx(:name, experiment_name)
        end

        def delete!(context=nil)
          combined.each { |combo| TrailGuide.catalog.find(combo).delete! }
          variants.each(&:delete!)
          deleted = adapter.destroy
          run_callbacks(:on_delete, context)
          true
        end

        def reset!(context=nil)
          delete!(context)
          save!
          run_callbacks(:on_reset, context)
          true
        end

        def storage_key
          configuration.name
        end
      end
    end
  end
end
