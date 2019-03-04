module TrailGuide
  module Adapters
    module Participants
      class Multi
        include Canfig::Instance

        class << self
          alias_method :configure, :new
          def new(context, &block)
            configure(&block).new(context)
          end
        end

        def initialize(&block)
          configure do |config|
            config.adapter = -> (context) do
              if context.respond_to?(:current_user, true) && context.send(:current_user).present?
                TrailGuide::Adapters::Participants::Redis
              elsif context.respond_to?(:cookies, true)
                TrailGuide::Adapters::Participants::Cookie
              elsif context.respond_to?(:session, true)
                TrailGuide::Adapters::Participants::Session
              else
                TrailGuide::Adapters::Participants::Anonymous
              end
            end

            yield(config) if block_given?
          end
        end

        # instance method, creates a new adapter and passes through config
        def new(context)
          adapter = configuration.adapter.call(context)
          adapter = configuration.send(adapter) if adapter.is_a?(Symbol)
          adapter.new(context)
        end
      end
    end
  end
end
