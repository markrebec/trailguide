module TrailGuide
  class Config < Canfig::Config
    DEFAULT_KEYS = [
      :redis, :disabled, :override_parameter, :allow_multiple_experiments,
      :adapter, :on_adapter_failover, :filtered_ip_addresses,
      :filtered_user_agents, :request_filter
    ].freeze

    def initialize(*args, **opts, &block)
      args = args.concat(DEFAULT_KEYS)
      super(*args, **opts, &block)
    end

    def configure(*args, &block)
      super(*args) do |config|
        yield(config, TrailGuide::Experiment.configuration) if block_given?
      end
    end

    def redis
      @redis ||= begin
        if ['Redis', 'Redis::Namespace'].include?(self[:redis].class.name)
          self[:redis]
        else
          Redis.new(url: self[:redis])
        end
      end
    end

    def filtered_user_agents
      @filtered_user_agents ||= begin
        uas = self[:filtered_user_agents]
        uas = uas.call if uas.respond_to?(:call)
        uas
      end
    end

    def filtered_ip_addresses
      @filtered_ip_addresses ||= begin
        ips = self[:filtered_ip_addresses]
        ips = ips.call if ips.respond_to?(:call)
        ips
      end
    end
  end
end
