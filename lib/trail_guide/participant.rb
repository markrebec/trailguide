module TrailGuide
  class Participant
    attr_reader :context
    delegate :key?, :keys, :[], :[]=, :delete, to: :adapter

    def initialize(context, adapter: nil)
      @context = context
      @adapter = adapter.new(context) unless adapter.nil?
    end

    def adapter
      @adapter ||= TrailGuide.configuration.adapter.new(context)
    end

    def participating!(experiment)
      # would this be better here instead of in experiment?
    end

    def checkpoint!(experiment, checkpoint=nil)
      # would this be better here instead of in experiment?
    end

    def variant(experiment)
      # would this be better here instead of in experiment?
    end
  end
end
