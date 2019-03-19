module TrailGuide
  module Admin
    class ExperimentsController < ::TrailGuide::Admin::ApplicationController
      before_action except: [:index] do
        (redirect_to :back rescue redirect_to trail_guide_admin.experiments_path) and return unless experiment.present?
      end

      def index
      end

      def start
        experiment.start!(self)
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def stop
        experiment.stop!(self)
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def reset
        experiment.reset!(self)
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def resume
        experiment.resume!(self)
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def restart
        experiment.reset!(self) && experiment.start!(self)
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def join
        participant.exit!(experiment)
        variant = experiment.variants.find { |var| var == params[:variant] }
        variant.increment_participation!
        participant.participating!(variant)
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def leave
        participant.exit!(experiment)
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def winner
        experiment.declare_winner!(params[:variant], self)
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def clear
        experiment.clear_winner!
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      private

      def experiment
        @experiment ||= TrailGuide.catalog.find(params[:id])
      end

      def participant
        @participant ||= TrailGuide::Participant.new(self)
      end
      helper_method :participant
    end
  end
end
