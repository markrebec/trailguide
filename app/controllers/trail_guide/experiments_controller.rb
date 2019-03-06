module TrailGuide
  class ExperimentsController < ::ApplicationController
    before_action :ensure_experiment, except: [:index]

    def index
      participant = TrailGuide::Participant.new(self)
      render json: {
        experiments: participant.active_experiments
      }
    end

    def choose
      variant = trailguide.choose!(experiment.experiment_name, metadata: metadata)
      render json: {
        experiment: experiment.experiment_name,
        variant: variant.name,
        metadata: variant.metadata.merge(metadata)
      }
    rescue => e
      render json: { error: e.message }, status: 500
    end

    def convert
      trailguide.convert!(experiment.experiment_name, checkpoint, metadata: metadata)
      render json: {
        experiment: experiment.experiment_name,
        checkpoint: checkpoint,
        metadata: metadata
      }
    rescue => e
      render json: { error: e.message }, status: 500
    end

    private

    def experiment
      @experiment ||= TrailGuide.catalog.find(params[:experiment_name])
    end

    def checkpoint
      @checkpoint ||= params[:checkpoint]
    end

    def metadata
      @metadata ||= params[:metadata].try(:permit!) || {}
    end

    def ensure_experiment
      render json: { error: "Experiment does not exist" }, status: 404 and return false unless experiment.present?
    end
  end
end
