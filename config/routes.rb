TrailGuide::Engine.routes.draw do
  get   '/:experiment_name' => 'application#choose',
        defaults: { format: :json }
  match '/:experiment_name' => 'application#convert',
        defaults: { format: :json },
        via: [:put, :post]
  match '/:experiment_name/:checkpoint' => 'application#convert',
        defaults: { format: :json },
        via: [:put, :post]
end
