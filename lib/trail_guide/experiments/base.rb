require "trail_guide/experiments/config"
require "trail_guide/experiments/persistence"
require "trail_guide/experiments/lifecycle"
require "trail_guide/experiments/enrollment"
require "trail_guide/experiments/conversion"
require "trail_guide/experiments/results"
require "trail_guide/experiments/participant"

module TrailGuide
  module Experiments
    class Base
      include Persistence
      include Lifecycle
      include Enrollment
      include Conversion
      include Results

      class << self
        delegate :groups, :algorithm, :control, :goals, :callbacks, :combined,
          :combined?, :allow_multiple_conversions?, :allow_multiple_goals?,
          :track_winner_conversions?, :start_manually?, :reset_manually?,
          :enable_calibration?, to: :configuration
        alias_method :funnels, :goals

        def register!
          TrailGuide.catalog.register(self)
        end

        def configuration
          @configuration ||= Experiments::Config.new(self)
        end

        def configure(*args, &block)
          configuration.configure(*args, &block)
        end

        # TODO alias name once specs have solid coverage
        def experiment_name
          configuration.name
        end

        def variants(include_control=true)
          if include_control
            configuration.variants
          else
            configuration.variants.select { |var| !var.control? }
          end
        end

        def is_combined?
          false
        end

        def combined_experiments
          combined.map { |combo| TrailGuide.catalog.find(combo) }
        end

        def as_json(opts={})
          { experiment_name => {
            started_at: started_at,
            paused_at: paused_at,
            stopped_at: stopped_at,
            winner: winner.try(:name),
            variants: variants.map(&:as_json).reduce({}) { |r,v| r.merge!(v) },
          } }
        end
      end

      attr_reader :participant
      delegate :configuration, :experiment_name, :variants, :control, :goals,
        :storage_key, :combined?, :start_manually?, :reset_manually?,
        :allow_multiple_conversions?, :allow_multiple_goals?, :is_combined?,
        :enable_calibration?, :track_winner_conversions?, :callbacks, to: :class
      delegate :context, to: :participant

      def initialize(participant)
        @participant = Experiments::Participant.new(self, participant)
      end

      def combined_experiments
        @combined_experiments ||= self.class.combined_experiments.map do |combo|
          combo.new(participant.participant)
        end
      end
    end
  end
end
