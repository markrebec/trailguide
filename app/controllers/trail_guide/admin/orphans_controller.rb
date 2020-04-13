module TrailGuide
  module Admin
    class OrphansController < ::TrailGuide::Admin::ApplicationController
      before_action except: [:index] do
        (redirect_to :back rescue redirect_to trail_guide_admin.orphans_path) unless orphan.present?
      end

      before_action :orphans, only: [:index]
      before_action :orphan,  only: [:show, :adopt]

      def index
      end

      def show
      end

      def adopt
        TrailGuide.catalog.adopted(@orphan.to_sym)
        flash[:success] = "Cleared references to <code>#{@orphan}</code>! It will reappear if it is encountered by users again."
        if TrailGuide.catalog.orphans.count > 0
          redirect_to trail_guide_admin.orphans_path
        else
          redirect_to trail_guide_admin.experiments_path
        end
      end

      private

      def orphans
        @orphans = TrailGuide.catalog.orphans
      end

      def orphan
        @orphan, @traces = TrailGuide.catalog.orphans.find { |orphan,_traces| orphan == params[:id].to_s.underscore }
      end
    end
  end
end
