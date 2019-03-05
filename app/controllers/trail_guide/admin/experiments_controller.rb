module TrailGuide
  module Admin
    class ExperimentsController < TrailGuide::Admin::ApplicationController
      before_action except: [:index] do
        (redirect_to :back rescue redirect_to trail_guide_admin.experiments_path) and return unless experiment.present?
      end

      def index
      end

      def start
        experiment.start!
        redirect_to :back rescue redirect_to trail_guide_admin.experiments_path
      end

      def stop
        experiment.stop!
        redirect_to :back rescue redirect_to trail_guide_admin.experiments_path
      end

      def reset
        experiment.reset!
        redirect_to :back rescue redirect_to trail_guide_admin.experiments_path
      end

      def restart
        experiment.reset! && experiment.start!
        redirect_to :back rescue redirect_to trail_guide_admin.experiments_path
      end

      def winner
        experiment.declare_winner!(params[:winner])
        redirect_to :back rescue redirect_to trail_guide_admin.experiments_path
      end

      private

      def experiment
        @experiment ||= TrailGuide.catalog.find(params[:id])
      end
    end
  end
end
