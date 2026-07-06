Rails.application.routes.draw do
  resource :session
  resource :registro, controller: "registrations", only: %i[ new create ]
  resources :passwords, param: :token

  # Login con Google (OmniAuth)
  get "auth/:provider/callback", to: "omniauth_sessions#create", as: :omniauth_callback
  get "auth/failure", to: "omniauth_sessions#failure"

  # Defines the root path route ("/")
  root "dashboard#show"

  # Nutrición y objetivos (SDD §09, Fase 4)
  resource :perfil, only: %i[ edit update ], controller: "perfiles"
  resource :objetivo, only: %i[ show new create ], controller: "objetivos"
  resources :registros_calorias, only: :create

  # Planes y monetización (SDD §09, Fase 5)
  get "mi_plan", to: "planes_personalizados#show", as: :mi_plan
  get "upgrade", to: "planes#index", as: :upgrade

  namespace :entrenador do
    resources :borradores, only: %i[ index show ], controller: "borradores" do
      resource :aprobacion, only: :create, controller: "aprobaciones"
    end
  end

  # Panel de administración (SDD §09) — protegido por Pundit, no solo por el namespace
  namespace :admin do
    resources :users, only: %i[ index show ]
    resources :membresias, only: %i[ index new create edit update ] do
      resource :renovacion, only: :create, controller: "renovaciones"
    end
    resources :pagos, only: :index
    resources :checkins, only: %i[ index create ]
    resources :suscripciones, only: %i[ index new create update ]
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
