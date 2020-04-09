require 'trail_guide/helper/helper_proxy'
require 'trail_guide/helper/experiment_proxy'

module TrailGuide
  module Helper
    def trailguide(key=nil, **opts, &block)
      @trailguide_proxy ||= HelperProxy.new(self)
      @trailguide_proxy = HelperProxy.new(self) if @trailguide_proxy.context != self
      return @trailguide_proxy if key.nil?
      @trailguide_proxy.choose!(key, **opts, &block)
    end

    def trailguide_participant
      @trailguide_participant ||= TrailGuide::Participant.new(self)
      @trailguide_participant = TrailGuide::Participant.new(self) if @trailguide_participant.context != self
      @trailguide_participant
    rescue => e
      TrailGuide.logger.error e
      @trailguide_participant = TrailGuide::Participant.new(self, adapter: Adapters::Participants::Anonymous)
    end

    # TODO maybe move this to the experiment proxy so it can be configured per-experiment
    def trailguide_excluded_request?
      @trailguide_excluded_request ||= instance_exec(self, &TrailGuide.configuration.request_filter)
    end

    def is_preview?
      return false unless respond_to?(:request, true)
      headers = request.try(:headers)
      headers && headers['x-purpose'] == 'preview'
    end

    def is_filtered_user_agent?
      return @is_filtered_user_agent unless @is_filtered_user_agent.nil?

      @is_filtered_user_agent = begin
        @user_agent_filter_proc ||= -> {
          return false if TrailGuide.configuration.filtered_user_agents.nil? || TrailGuide.configuration.filtered_user_agents.empty?
          return false unless respond_to?(:request, true) && request.user_agent

          TrailGuide.configuration.filtered_user_agents.each do |ua|
            return true if ua.class == String && request.user_agent == ua
            return true if ua.class == Regexp && request.user_agent =~ ua
          end

          return false
        }
        instance_exec(&@user_agent_filter_proc)
      end
    end

    def is_filtered_ip_address?
      return @is_filtered_ip_address unless @is_filtered_ip_address.nil?

      @is_filtered_ip_address = begin
        @ip_address_filter_proc ||= -> {
          return false if TrailGuide.configuration.filtered_ip_addresses.nil? || TrailGuide.configuration.filtered_ip_addresses.empty?
          return false unless respond_to?(:request, true) && request.ip

          TrailGuide.configuration.filtered_ip_addresses.each do |ip|
            return true if ip.class == String && request.ip == ip
            return true if ip.class == Regexp && request.ip =~ ip
            return true if ip.class == Range && ip.first.class == IPAddr && ip.include?(IPAddr.new(request.ip))
          end

          return false
        }
        instance_exec(&@ip_address_filter_proc)
      end
    end
  end
end
