module TrailGuide
  module Admin
    class ExperimentsController < ::TrailGuide::Admin::ApplicationController
      before_action except: [:index] do
        (redirect_to :back rescue redirect_to trail_guide_admin.experiments_path) and return unless experiment.present?
      end

      before_action :experiments, only: [:index]
      before_action :experiment,  except: [:index]

      def index
      end

      def show
      end

      def start
        experiment.reset!(self) if experiment.enable_calibration?
        experiment.start!(self)

        flash[:success] = "Experiment started"
        redirect_to_experiment experiment
      end

      def schedule
        experiment.schedule!(schedule_params[:start_at], schedule_params[:stop_at], self)

        flash[:success] = "Experiment scheduled for <strong>#{experiment.started_at.strftime(TrailGuide::Admin::DISPLAY_DATE_FORMAT)}</strong>"
        redirect_to_experiment experiment
      rescue => e
        flash[:danger] = e.message
        redirect_to_experiment experiment
      end

      def pause
        experiment.pause!(self)

        flash[:success] = "Experiment paused"
        redirect_to_experiment experiment
      end

      def stop
        experiment.stop!(self)

        flash[:success] = "Experiment stopped"
        redirect_to_experiment experiment
      end

      def reset
        experiment.stop!(self)
        experiment.reset!(self)

        flash[:success] = "Experiment reset"
        redirect_to_experiment experiment
      end

      def resume
        experiment.resume!(self)

        flash[:success] = "Experiment resumed"
        redirect_to_experiment experiment
      end

      def restart
        experiment.stop!(self)
        experiment.reset!(self)
        experiment.start!(self)

        flash[:success] = "Experiment restarted"
        redirect_to_experiment experiment
      end

      def enroll
        variant = enroll_experiment(experiment)
        flash[:info] = "You were enrolled in the <strong>#{variant.to_s.humanize.titleize}</strong> variant"
        redirect_to_experiment experiment
      end

      def convert
        params[:goal] = nil if params[:goal] == 'converted'
        variant = convert_experiment(experiment, params[:goal])
        if variant
          flash[:info] = "You successfully converted the goal <strong>#{params[:goal].to_s.humanize.titleize}</strong> in the <strong>#{variant.to_s.humanize.titleize}</strong> variant"
        else
          flash[:info] = "You did not convert the goal <strong>#{params[:goal].to_s.humanize.titleize}</strong>"
        end
        redirect_to_experiment experiment
      end

      def join
        join_experiment(experiment)
        flash[:success] = "You joined the <strong>#{params[:variant].to_s.humanize.titleize}</strong> cohort"
        redirect_to_experiment experiment
      end

      def leave
        leave_experiment(experiment)
        flash[:success] = "You left the experiment"
        redirect_to_experiment experiment
      end

      def winner
        experiment.declare_winner!(params[:variant], self)
        flash[:success] = "Declared <strong>#{params[:variant].to_s.humanize.titleize}</strong> as the winner"
        redirect_to_experiment experiment
      end

      def clear
        experiment.clear_winner!
        flash[:success] = "Removed the winner"
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

      def enroll_experiment(experiment)
        if experiment.is_combined?
          experiment.new(participant).choose!
        else
          leave_experiment(experiment)
          variant = experiment.new(participant).choose!
          if experiment.combined?
            experiment.combined_experiments.each do |expmt|
              expmt.new(participant).choose!
            end
          end
          variant
        end
      end

      def convert_experiment(experiment, checkpoint=nil)
        return false if experiment.combined?
        experiment.new(participant).convert!(checkpoint)
      end

      def join_experiment(experiment)
        leave_experiment(experiment)
        if experiment.is_combined?
          variant = experiment.parent.variants.find { |var| var == params[:variant] }
          variant.increment_participation!
          participant.participating!(variant)
          experiment.parent.combined_experiments.each do |expmt|
            variant = expmt.variants.find { |var| var == params[:variant] }
            variant.increment_participation!
            participant.participating!(variant)
          end
        else
          variant = experiment.variants.find { |var| var == params[:variant] }
          variant.increment_participation!
          participant.participating!(variant)
          if experiment.combined?
            experiment.combined_experiments.each do |expmt|
              variant = expmt.variants.find { |var| var == params[:variant] }
              variant.increment_participation!
              participant.participating!(variant)
            end
          end
        end
      end

      def leave_experiment(experiment)
        if experiment.is_combined?
          participant.exit!(experiment.parent)
          experiment.parent.combined_experiments.each do |expmt|
            participant.exit!(expmt)
          end
        else
          participant.exit!(experiment)
          if experiment.combined?
            experiment.combined_experiments.each do |expmt|
              participant.exit!(expmt)
            end
          end
        end
      end

      def participant
        @participant ||= TrailGuide::Participant.new(self)
      end
      helper_method :participant

      def redirect_to_experiment(experiment)
        if experiment <= TrailGuide::CombinedExperiment
          redirect_back fallback_location: trail_guide_admin.experiment_path(experiment.parent.experiment_name)
        else
          redirect_to trail_guide_admin.experiment_path(experiment.experiment_name)
        end
      end
    end
  end
end
