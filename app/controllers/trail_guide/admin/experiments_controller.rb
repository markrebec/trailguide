module TrailGuide
  module Admin
    class ExperimentsController < ::TrailGuide::Admin::ApplicationController
      before_action except: [:index] do
        (redirect_to :back rescue redirect_to trail_guide_admin.experiments_path) and return unless experiment.present?
      end

      before_action :experiments, only: [:index]
      before_action :experiment,  only: [:show]

      def index
      end

      def show
      end

      def start
        experiment.start!(self)
        redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
      end

      def schedule
        experiment.schedule!(schedule_params[:start_at], schedule_params[:stop_at], self)
        redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
      rescue => e
        flash[:danger] = e.message
        redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
      end

      def pause
        experiment.pause!(self)
        redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
      end

      def stop
        experiment.stop!(self)
        redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
      end

      def reset
        experiment.stop!(self)
        experiment.reset!(self)
        redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
      end

      def resume
        experiment.resume!(self)
        redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
      end

      def restart
        experiment.stop!(self)
        experiment.reset!(self)
        experiment.start!(self)
        redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
      end

      def join
        participant.exit!(experiment)
        variant = experiment.variants.find { |var| var == params[:variant] }
        variant.increment_participation!
        participant.participating!(variant)
        redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
      end

      def leave
        participant.exit!(experiment)
        redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
      end

      def winner
        experiment.declare_winner!(params[:variant], self)
        redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
      end

      def clear
        experiment.clear_winner!
        redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
      end

      private

      def experiments
        @experiments = TrailGuide.catalog
        @experiments = @experiments.send(params[:scope]) if params[:scope].present?
        @experiments = @experiments.by_started
      end

      def experiment
        @experiment ||= TrailGuide.catalog.find(params[:id])
      end

      def schedule_params
        @schedule_params ||= begin
          exp_params = params.require(:experiment).permit(:start_at, :stop_at)
          exp_params[:start_at] = DateTime.parse(exp_params[:start_at]) rescue raise(ArgumentError, "Invalid start date")
          exp_params[:stop_at] = (DateTime.parse(exp_params[:stop_at]) rescue nil)
          raise ArgumentError, "Experiments cannot be scheduled to stop before they start" if exp_params[:stop_at] && exp_params[:stop_at] <= exp_params[:start_at]
          exp_params
        end
      end

      def participant
        @participant ||= TrailGuide::Participant.new(self)
      end
      helper_method :participant
    end
  end
end
