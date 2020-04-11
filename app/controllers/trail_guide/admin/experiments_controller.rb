require 'json'

module TrailGuide
  module Admin
    class ExperimentsController < ::TrailGuide::Admin::ApplicationController
      before_action except: [:index, :import] do
        (redirect_to :back rescue redirect_to trail_guide_admin.experiments_path) and return unless experiment.present?
      end

      before_action :experiments, only: [:index]
      before_action :experiment,  except: [:index, :import]

      def index
        respond_to do |format|
          format.html { render }
          format.json {
            send_data JSON.pretty_generate(TrailGuide.catalog.export),
            filename: "trailguide-#{Rails.env}-#{Time.now.to_i}.json"
          }
        end
      end

      def import
        import_file = params[:file]

        if import_file
          if import_file.respond_to?(:read)
            state_json = JSON.load(import_file.read)
          elsif import_file.respond_to?(:path)
            state_json= JSON.load(File.read(import_file.path))
          end
          TrailGuide.catalog.import(state_json)
          flash[:success] = "Experiment state imported successfully"
          redirect_to trail_guide_admin.experiments_path
        else
          raise "Please provide an import file"
        end
      rescue => e
        flash[:error] = "There was a problem importing this file: #{e.message}"
        redirect_to trail_guide_admin.experiments_path
      end

      def show
        @analyzing = params.key?(:analyze)
        @analyze_goal = params[:goal].present? ?
          params[:goal].underscore.to_sym :
          experiment.goals.first.try(:name)
        @analyze_method = params[:method].present? ?
          params[:method].underscore.to_sym :
          :score
      end

      def start
        experiment.reset!(self) if experiment.enable_calibration?
        experiment.start!(self)

        flash[:success] = "Experiment started"
        redirect_to_experiment experiment
      end

      def schedule
        experiment.schedule!(schedule_params[:start_at], schedule_params[:stop_at], self)

        flash[:success] = "Experiment scheduled for <strong>#{format_time(experiment.started_at)}</strong>"
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
        # TODO handle explicitly joining combined experiments
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
        participant.exit!(experiment)
        if experiment.combined?
          experiment.combined_experiments.each do |expmt|
            participant.exit!(expmt)
          end
        end
      end

      def participant
        @participant ||= TrailGuide::Participant.new(self)
      end
      helper_method :participant

      def experiment_calculator(experiment, **opts)
        klass = "TrailGuide::Calculators::#{@analyze_method.to_s.classify}".constantize
        calculator = klass.new(experiment, **{base: :control, goal: @analyze_goal}.merge(opts))
        calculator.calculate! if @analyzing
        calculator
      end
      helper_method :experiment_calculator

      def variant_analysis_color(variant, calculator)
        if !@analyzing || !experiment_metrics_visible?(calculator.experiment)
          'dark'
        elsif variant.measure > 0
          if variant == calculator.base
            'dark'
          elsif variant.measure == calculator.best.measure
            'success'
          elsif variant.measure == calculator.worst.measure
            'danger'
          elsif variant.measure > calculator.base.measure
            'info'
          elsif variant.measure < calculator.base.measure
            'warning'
          end
        else
          'muted'
        end
      end
      helper_method :variant_analysis_color

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
