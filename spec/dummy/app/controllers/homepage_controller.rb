class HomepageController < ApplicationController
  def index
    trailguide.convert!(:non_existent_group)
    trailguide.choose!(:multi_goal_example)
    trailguide.convert!(:multi_goal_example, [:first, :second].sample)
  end
end
