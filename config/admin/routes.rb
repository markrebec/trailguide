TrailGuide::Admin::Engine.routes.draw do
  resources :experiments, path: '/', only: [:index] do
    member do
      match :start,   via: [:put, :post, :get]
      match :stop,    via: [:put, :post, :get]
      match :reset,   via: [:put, :post, :get]
      match :restart, via: [:put, :post, :get]
      match 'winner/:winner', action: :winner, as: :winner, via: [:put, :post, :get]
    end
  end
end
