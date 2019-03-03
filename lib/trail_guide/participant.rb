module TrailGuide
  class Participant
    attr_reader :context
    delegate :key?, :keys, :[], :[]=, :delete, :to_h, to: :adapter

    def initialize(context, adapter: nil)
      @context = context
      @adapter = adapter.new(context) unless adapter.nil?
    end

    def adapter
      @adapter ||= begin
        config_adapter = TrailGuide.configuration.adapter
        config_adapter = config_adapter.constantize if config_adapter.is_a?(String)
        config_adapter.new(context)
      end
    end

    def participating_in_active_experiments?
      return false if adapter.keys.empty?

      keys.any? do |key|
        experiment_name = key.split(":").first.to_sym
        experiment = TrailGuide.catalog.find(experiment_name)
        experiment && experiment.started? && experiment.participating?(self)
      end
    end
  end
end
