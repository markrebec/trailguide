module TrailGuide
  module Admin
    class ExperimentsController < ::TrailGuide::Admin::ApplicationController
      before_action except: [:index] do
        (redirect_to :back rescue redirect_to trail_guide_admin.experiments_path) and return unless experiment.present?
      end

      def index
      end

      def start
        experiment.start!
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def stop
        experiment.stop!
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def reset
        experiment.reset!
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def resume
        experiment.resume!
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def restart
        experiment.reset! && experiment.start!
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      def winner
        experiment.declare_winner!(params[:variant])
        redirect_to trail_guide_admin.experiments_path(anchor: experiment.experiment_name)
      end

      private

      def experiment
        @experiment ||= TrailGuide.catalog.find(params[:id])
      end
    end
  end
end
