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
