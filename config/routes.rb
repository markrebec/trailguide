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
end

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
      # There is a weird bug (sorta?), where because we're including two rails
      # engines within this gem, they both end up pulling in these route configs
      # which causes the routes to be redefined a second time, which in turn
      # causes named routes (using the `:as` key) to raise an error.
      #
      # This rescues that failure on the second pass, while still allowing the
      # routes to be defined properly.
      get  '/:scope', action: :index, as: :scoped rescue nil
    end
  end
end
