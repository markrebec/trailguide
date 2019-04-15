TrailGuide::Admin::Engine.routes.draw do
  resources :experiments, path: '/', only: [:index] do
    member do
      match :start,   via: [:put, :post, :get]
      match :pause,   via: [:put, :post, :get]
      match :stop,    via: [:put, :post, :get]
      match :reset,   via: [:put, :post, :get]
      match :resume,  via: [:put, :post, :get]
      match :restart, via: [:put, :post, :get]

      match :join,    via: [:put, :post, :get], path: 'join/:variant'
      match :leave,   via: [:put, :post, :get]

      match :winner,  via: [:put, :post, :get], path: 'winner/:variant'
      match :clear,   via: [:put, :post, :get]
    end

    collection do
      get  '/:scope', action: :index, as: :scoped
    end
  end
end
