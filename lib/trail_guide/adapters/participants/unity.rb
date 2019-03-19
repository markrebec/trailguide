require 'trail_guide/unity'

module TrailGuide
  module Adapters
    module Participants
      class Unity < Multi
        attr_reader :context, :unity

        def initialize(&block)
          configure do |config|
            config.visitor_cookie = nil
            config.user_id_key = :id

            config.user_adapter = TrailGuide::Adapters::Participants::Redis.configure do |config|
              config.namespace = 'unity:users'
              config.lookup = -> (user_id) { user_id }
              config.expiration = 1.year.seconds
            end

            config.visitor_adapter = TrailGuide::Adapters::Participants::Redis.configure do |config|
              config.namespace = 'unity:visitors'
              config.lookup = -> (visitor_id) { visitor_id }
              config.expiration = 1.year.seconds
            end

            config.anonymous_adapter = TrailGuide::Adapters::Participants::Anonymous

            yield(config) if block_given?
          end
        end

        def new(context)
          @context = context
          @unity = TrailGuide::Unity.new

          if trailguide_context?
            unity.user_id ||= context.send(:try, :trailguide_user).try(configuration.user_id_key)
            unity.visitor_id ||= context.send(:try, :trailguide_visitor)
          end

          if logged_in_context?
            unity.user_id ||= context.send(:current_user).send(configuration.user_id_key)
          end

          if logged_out_context?
            unity.visitor_id ||= context.send(:cookies)[configuration.visitor_cookie].gsub(/(%22|")/, '')
          end

          unity.sync!
          merge! if unity.synced?

          adapter = configuration.send("#{context_type}_adapter".to_sym)
          if anonymous_context?
            adapter.new(context)
          else
            adapter.new(unity.send("#{context_type}_id".to_sym))
          end
        end

        protected

        def context_type
          if visitor_context?
            return :visitor
          end

          if user_context?
            return :user
          end

          return :anonymous
        end

        def merge!
          user_adapter = configuration.user_adapter.new(unity.user_id)
          visitor_adapter = configuration.visitor_adapter.new(unity.visitor_id)
          user_adapter.keys.each do |key|
            visitor_adapter[key] = user_adapter[key] unless visitor_adapter[key].present?
          end
          user_adapter.destroy!
        end

        def trailguide_context?
          context.send(:try, :trailguide_user).present? ||
            context.send(:try, :trailguide_visitor).present?
        end

        def logged_in_context?
          context.send(:try, :current_user).present?
        end

        def logged_out_context?
          return false unless configuration.visitor_cookie.present?
          context.send(:cookies)[configuration.visitor_cookie].present?
        rescue => e
          return false
        end

        def user_context?
          unity.user_id.present?
        end

        def visitor_context?
          unity.visitor_id.present?
        end

        def anonymous_context?
          !visitor_context? && !user_context?
        end
      end
    end
  end
end
