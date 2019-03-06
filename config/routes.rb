TrailGuide::Engine.routes.draw do
  get   '/' => 'experiments#index',
        defaults: { format: :json }
  get   '/:experiment_name' => 'experiments#choose',
        defaults: { format: :json }
  match '/:experiment_name' => 'experiments#convert',
        defaults: { format: :json },
        via: [:put, :post]
  match '/:experiment_name/:checkpoint' => 'experiments#convert',
        defaults: { format: :json },
        via: [:put, :post]
end

if defined?(TrailGuide::Admin::Engine)
  TrailGuide::Admin::Engine.routes.draw do
    resources :experiments, path: '/', only: [:index] do
      member do
        match :start,   via: [:put, :post, :get]
        match :stop,    via: [:put, :post, :get]
        match :reset,   via: [:put, :post, :get]
        match :restart, via: [:put, :post, :get]
        match :winner,  via: [:put, :post, :get], path: 'winner/:variant'
      end
    end
  end
end
