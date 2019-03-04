Rails.application.routes.draw do
  mount TrailGuide::Engine => "/trailguide"

  root to: 'homepage#index'
end
