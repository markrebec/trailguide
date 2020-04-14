module TrailGuide
  module Adapters
    module Participants
      class Base
        include Canfig::Instance

        class << self
          alias_method :configure, :new
          def new(context, &block)
            configure(&block).new(context)
          end
        end

        def initialize(&block)
          configure(&block) if block_given?
        end

        def new(context)
          self.class::Adapter.new(context, configuration)
        end

        class Adapter
          attr_reader :context, :config
          alias_method :configuration, :config

          def initialize(context, config)
            @context = context
            @config = config
          end

          def subject
            context.try(:trailguide_user) || context.try(:current_user)
          end
          alias_method :user, :subject

          def [](key)
            raise NotImplementedError, "You must override the `[]` method in your inheriting adapter class"
          end

          def []=(key, value)
            raise NotImplementedError, "You must override the `[]=` method in your inheriting adapter class"
          end

          def delete(key)
            raise NotImplementedError, "You must override the `delete` method in your inheriting adapter class"
          end

          def destroy!
            raise NotImplementedError, "You must override the `destroy!` method in your inheriting adapter class"
          end

          def keys
            raise NotImplementedError, "You must override the `keys` method in your inheriting adapter class"
          end

          def key?(key)
            raise NotImplementedError, "You must override the `key?` method in your inheriting adapter class"
          end

          def to_h
            raise NotImplementedError, "You must override the `to_h` method in your inheriting adapter class"
          end
        end
      end
    end
  end
end
