require "trail_guide/admin"

Rails.application.routes.draw do

  mount TrailGuide::Engine => "/trailguide"
  mount TrailGuide::Admin::Engine => "/admin/trailguide"

  root to: 'homepage#index'
end
