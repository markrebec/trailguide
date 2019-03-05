TrailGuide::Admin::Engine.routes.draw do
  resources :experiments, only: [:index]
end
