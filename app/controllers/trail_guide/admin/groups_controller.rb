module TrailGuide
  module Admin
    class GroupsController < ::TrailGuide::Admin::ApplicationController
      before_action except: [:index] do
        (redirect_to :back rescue redirect_to trail_guide_admin.experiments_path) and return unless group.present?
      end

      before_action :groups,      only: [:index]
      before_action :group,       only: [:show]
      before_action :experiments, only: [:show]

      def index
      end

      def show
      end

      private

      def groups
        @groups = TrailGuide.catalog.groups
      end

      def group
        @group ||= TrailGuide.catalog.groups.find { |group| group == params[:id].to_s.underscore.to_sym }
      end

      def experiments
        @experiments = TrailGuide.catalog.select(params[:id])
        @experiments = @experiments.by_started
      end
    end
  end
end
