module TrailGuide
  class ApplicationController < ::ApplicationController
    def choose
      variant = trailguide.choose!(experiment_param, metadata: metadata_param)
      render json: {
        experiment: experiment_param,
        variant: variant.name,
        metadata: variant.metadata.merge(metadata_param)
      }
    end

    def convert
      trailguide.convert!(experiment_param, checkpoint_param, metadata: metadata_param)
      render json: {
        experiment: experiment_param,
        checkpoint: checkpoint_param,
        metadata: metadata_param
      }
    end

    private

    def experiment_param
      @experiment_param ||= params[:experiment_name]
    end

    def checkpoint_param
      @checkpoint_param ||= params[:checkpoint]
    end

    def metadata_param
      @metadata_param ||= params[:metadata].try(:permit!) || {}
    end
  end
end
