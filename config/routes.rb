Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :appointments do
    member do
      patch :cancel
    end
    collection do
      get  :check_availability
      post :check_availability, action: :check_availability
    end
  end
  resources :dealerships,    only: %i[index show]
  resources :service_types,  only: %i[index show]
  resources :customers,      only: %i[index show new create] do
    resources :vehicles, only: %i[new create index]
  end

  # Defines the root path route ("/")
  root "appointments#index"
end
