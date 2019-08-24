module TrailGuide
  class Config < Canfig::Config
    DEFAULT_KEYS = [
      :logger, :redis, :disabled, :override_parameter,
      :allow_multiple_experiments, :adapter, :on_adapter_failover,
      :filtered_ip_addresses, :filtered_user_agents, :request_filter,
      :include_helpers, :cleanup_participant_experiments, :unity_ttl,
      :ignore_orphaned_groups
    ].freeze

    def initialize(*args, **opts, &block)
      args = args.concat(DEFAULT_KEYS)
      super(*args, **opts, &block)
    end

    def paths
      @paths ||= Struct.new(:configs, :classes).new([],[])
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

    def ignore_orphaned_groups?
      !!self[:ignore_orphaned_groups]
    end

    def filtered_user_agents
      @filtered_user_agents ||= begin
        uas = self[:filtered_user_agents]
        uas = uas.call if uas.respond_to?(:call)
        uas || []
      end
    end

    def filtered_ip_addresses
      @filtered_ip_addresses ||= begin
        ips = self[:filtered_ip_addresses]
        ips = ips.call if ips.respond_to?(:call)
        ips || []
      end
    end
  end
end
