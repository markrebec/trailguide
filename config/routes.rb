# we use the `routes_loaded` class attributes on the engine classes to track
# whether routes have been loaded already.
#
# because there are two rails engines in this gem, and because of the way rails
# engines and routes work, this route config will be included twice, and attempt
# to redefine named routes, which causes rails to raise an exception

TrailGuide::Engine.routes.draw do
  get   '/' => 'experiments#index',
        defaults: { format: :json }
  match '/:experiment_name' => 'experiments#choose',
        defaults: { format: :json },
        via: [:get, :post]
  match '/:experiment_name' => 'experiments#convert',
        defaults: { format: :json },
        via: [:put]
  match '/:experiment_name/:checkpoint' => 'experiments#convert',
        defaults: { format: :json },
        via: [:put]

  TrailGuide::Engine.routes_loaded = true
end unless TrailGuide::Engine.routes_loaded

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

  TrailGuide::Admin::Engine.routes_loaded = true
end unless TrailGuide::Admin::Engine.routes_loaded
