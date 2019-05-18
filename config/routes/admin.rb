TrailGuide::Admin::Engine.routes.draw do
  resources :groups, only: [:index, :show]

  resources :experiments, path: '/', only: [:index, :show] do
    member do
      match :start,    via: [:put, :post, :get]
      match :schedule, via: [:put, :post]
      match :pause,    via: [:put, :post, :get]
      match :stop,     via: [:put, :post, :get]
      match :reset,    via: [:put, :post, :get]
      match :resume,   via: [:put, :post, :get]
      match :restart,  via: [:put, :post, :get]

      match :enroll,   via: [:put, :post, :get], path: 'enroll'
      match :join,     via: [:put, :post, :get], path: 'join/:variant'
      match :convert,  via: [:put, :post, :get], path: 'convert/:goal'
      match :leave,    via: [:put, :post, :get]

      match :winner,   via: [:put, :post, :get], path: 'winner/:variant'
      match :clear,    via: [:put, :post, :get]
    end

    collection do
      get  '/scope/:scope', action: :index, as: :scoped
    end
  end
end
