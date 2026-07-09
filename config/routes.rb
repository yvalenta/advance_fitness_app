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

  # Progreso (SDD §09 — mitad adelantada de la Fase 3, ver nota §11)
  resource :progreso, only: :show, controller: "progresos"

  # Auto-registro de peso del miembro (Fase 5.9): crea una medición propia.
  resources :mediciones, only: :create

  # Seguimiento de entrenamiento del miembro (Fase 5.10): upsert por fecha+ejercicio.
  resources :registros_entrenamiento, only: :create

  # Planes y monetización (SDD §09, Fase 5)
  get "mi_plan", to: "planes_personalizados#show", as: :mi_plan
  get "upgrade", to: "planes#index", as: :upgrade

  # Editor de plan compartido por entrenador y admin (SDD Fase 5.6) —
  # autorizado por Pundit (editar?/publicar?), no por el namespace.
  resources :planes_personalizados, only: %i[ show update ], controller: "gestion_planes" do
    member do
      post :publicar
      post :regenerar
    end
    resources :comidas, only: %i[ create update destroy ], controller: "gestion_comidas"
    # Rutina 2D: día (índice) → ejercicios (índice); autosave por URL
    resources :dias, only: %i[ update ], controller: "gestion_dias" do
      resources :ejercicios, only: %i[ create update destroy ], controller: "gestion_ejercicios"
    end
  end

  namespace :entrenador do
    resources :borradores, only: %i[ index ], controller: "borradores"
    resources :plantillas_comida, only: %i[ create destroy ], controller: "plantillas_comida"
    resources :plantillas_ejercicio, only: %i[ create destroy ], controller: "plantillas_ejercicio"
  end

  # Panel de administración (SDD §09) — protegido por Pundit, no solo por el namespace
  namespace :admin do
    resources :users, only: %i[ index show ] do
      # Antropometría con historial, tomada por el staff (Fase 5.9)
      resources :mediciones, only: %i[ index new create ]
    end
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
