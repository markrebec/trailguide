TrailGuide::Engine.routes.draw do
  get   '/:experiment_name' => 'experiments#choose',
        defaults: { format: :json }
  match '/:experiment_name' => 'experiments#convert',
        defaults: { format: :json },
        via: [:put, :post]
  match '/:experiment_name/:checkpoint' => 'experiments#convert',
        defaults: { format: :json },
        via: [:put, :post]
end
