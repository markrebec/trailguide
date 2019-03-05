TrailGuide::Admin::Engine.routes.draw do
  resources :experiments, path: '/', only: [:index] do
    member do
      match :start,   via: [:put, :post]
      match :stop,    via: [:put, :post]
      match :reset,   via: [:put, :post]
      match :restart, via: [:put, :post]
      match 'winner/:winner', action: :winner, as: :winner, via: [:put, :post]
    end
  end
end
