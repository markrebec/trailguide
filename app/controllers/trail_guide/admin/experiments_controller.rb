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
        experiment.reset!(self) if experiment.enable_calibration?
        experiment.start!(self)
        redirect_to_experiment experiment
      end

      def schedule
        experiment.schedule!(schedule_params[:start_at], schedule_params[:stop_at], self)
        redirect_to_experiment experiment
      rescue => e
        flash[:danger] = e.message
        redirect_to_experiment experiment
      end

      def pause
        experiment.pause!(self)
        redirect_to_experiment experiment
      end

      def stop
        experiment.stop!(self)
        redirect_to_experiment experiment
      end

      def reset
        experiment.stop!(self)
        experiment.reset!(self)
        redirect_to_experiment experiment
      end

      def resume
        experiment.resume!(self)
        redirect_to_experiment experiment
      end

      def restart
        experiment.stop!(self)
        experiment.reset!(self)
        experiment.start!(self)
        redirect_to_experiment experiment
      end

      def enroll
        variant = enroll_experiment(experiment)
        flash[:info] = "You were enrolled in the <strong>#{variant.to_s.humanize.titleize}</strong> variant"
        redirect_to_experiment experiment
      end

      def join
        if experiment <= TrailGuide::CombinedExperiment
          experiment.parent.combined_experiments.each do |expmt|
            join_experiment(expmt)
          end
        else
          join_experiment(experiment)
        end

        redirect_to_experiment experiment
      end

      def leave
        if experiment <= TrailGuide::CombinedExperiment
          experiment.parent.combined_experiments.each do |expmt|
            leave_experiment(expmt)
          end
        elsif experiment.combined?
          leave_experiment(experiment)
          experiment.combined_experiments.each do |expmt|
            leave_experiment(expmt)
          end
        else
          leave_experiment(experiment)
        end

        redirect_to_experiment experiment
      end

      def winner
        experiment.declare_winner!(params[:variant], self)
        redirect_to_experiment experiment
      end

      def clear
        experiment.clear_winner!
        redirect_to_experiment experiment
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
          start_at = exp_params[:start_at]
          stop_at = exp_params[:stop_at]

          exp_params[:start_at] = DateTime.strptime(exp_params[:start_at], TrailGuide::SCHEDULE_DATE_FORMAT) rescue raise(ArgumentError, "Invalid start date")
          raise ArgumentError, "Invalid start date" unless exp_params[:start_at].strftime(TrailGuide::SCHEDULE_DATE_FORMAT) == start_at

          exp_params[:stop_at] = (DateTime.strptime(exp_params[:stop_at], TrailGuide::SCHEDULE_DATE_FORMAT) rescue nil)
          if exp_params[:stop_at]
            raise ArgumentError, "Invalid stop date" unless exp_params[:stop_at].strftime(TrailGuide::SCHEDULE_DATE_FORMAT) == stop_at

            raise ArgumentError, "Experiments cannot be scheduled to stop before they start" if exp_params[:stop_at] <= exp_params[:start_at]
          end

          exp_params
        end
      end

      def enroll_experiment(expmt)
        participant.exit!(expmt)
        expmt.new(participant).choose!
      end

      def join_experiment(expmt)
        participant.exit!(expmt)
        variant = expmt.variants.find { |var| var == params[:variant] }
        variant.increment_participation!
        participant.participating!(variant)
      end

      def leave_experiment(expmt)
        participant.exit!(expmt)
      end

      def participant
        @participant ||= TrailGuide::Participant.new(self)
      end
      helper_method :participant

      def redirect_to_experiment(experiment)
        if experiment <= TrailGuide::CombinedExperiment
          redirect_to trail_guide_admin.experiment_path(experiment.parent.experiment_name, anchor: experiment.experiment_name)
        else
          redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
        end
      end
    end
  end
end
