Rails.application.routes.draw do
  # Autoservicio (Fase 12b, SDD §17.5): dos dominios dedicados, uno por
  # audiencia — sin toggle, cada uno habla solo a la suya. Cobro manual, el
  # comercializador cierra desde el portal comercial.
  constraints(subdomain: /\A(trainer|entrena)\z/) do
    get  "/",        to: "landing/autoservicios#new",     as: :landing_autoservicio
    post "/",         to: "landing/autoservicios#create",  as: :landing_autoservicios
    get  "/gracias",  to: "landing/autoservicios#gracias", as: :landing_autoservicio_gracias
  end

  # Landing de campaña: join.ynt.codes/:slug → página pública de conversión
  # de un tenant existente (SDD §16.6/§Fase 13). Dominio propio, sin relación
  # con el autoservicio de arriba.
  constraints(subdomain: /\A(join|unete)\z/) do
    get "/:slug",         to: "landing/campanas#show",   as: :landing_campana
    get "/:slug/unirse",  to: "landing/campanas#unirse", as: :landing_unirse
  end

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
  # Credenciales de la cuenta (Fase 17): correo/contraseña con password_challenge
  resource :cuenta, only: :update, controller: "cuentas"
  resource :objetivo, only: %i[ show new create update ], controller: "objetivos"
  resources :registros_calorias, only: :create

  # Progreso (SDD §09 — mitad adelantada de la Fase 3, ver nota §11)
  resource :progreso, only: :show, controller: "progresos"
  # Gráficas perezosas por scroll (Fase 16.6): cada turbo-frame trae SOLO su
  # serie — la página del miembro carga el resumen y nada más.
  get "progreso/grafica/:tipo", to: "progreso_graficas#show", as: :progreso_grafica,
      constraints: { tipo: /peso|calorias|asistencia|una_rm|heatmap|mapa_muscular/ }

  # Auto-registro de peso del miembro (Fase 5.9): crea una medición propia.
  resources :mediciones, only: :create

  # Seguimiento de entrenamiento del miembro (Fase 5.10): upsert por fecha+ejercicio.
  resources :registros_entrenamiento, only: :create

  # Ciclo menstrual (Fase 14.15) — dato de salud sensible, siempre en primera
  # persona: no hay rutas de staff/admin para estos recursos y la card vive
  # solo en /progreso. El consentimiento es un recurso singular: POST otorga
  # (con opt-in separado de IA), DELETE revoca — y borra los ciclos salvo
  # "conservar mis datos" (ver ConsentimientosCicloController).
  resources :ciclos_menstruales, only: %i[ create destroy ]
  resource :consentimiento_ciclo, only: %i[ create destroy ], controller: "consentimientos_ciclo"

  # Web Push (Fase 15, Nota 20): el dispositivo actual se suscribe o se
  # retira, siempre en primera persona; la identidad es el endpoint que
  # manda el propio navegador — no se acepta ningún id.
  post "suscripciones_push", to: "suscripciones_push#create", as: :suscripciones_push
  delete "suscripciones_push", to: "suscripciones_push#destroy"

  # Registro cuantitativo de series (SDD §18, feature premium): index carga
  # el dialog por fecha+ejercicio (query string, mismo patrón de :ayuda);
  # create/destroy responden turbo_stream. Rutas nombradas a mano (en vez de
  # `resources`) para no depender del inflector global: el nombre de tabla
  # real "detalle_entrenamientos" no coincide con "detalles_entrenamiento".
  # Solo el POST del modo sesión (Fase 18n): el dialog de registro (GET) y el
  # quitar serie (DELETE) se eliminaron con su UI — eran superficie muerta
  # desde que la sesión captura las series al tap (18l).
  post "detalles_entrenamiento", to: "detalles_entrenamiento#create", as: :detalles_entrenamiento
  # Analista de Performance (SDD §18.4): dispara AnalizarEntrenamientoJob.
  post "detalles_entrenamiento/analizar", to: "detalles_entrenamiento#analizar", as: :analizar_entrenamiento

  # Catálogo visual de ejercicios (Fase 6): búsqueda, popup de ayuda y media
  # (GIF/imagen del dataset) servida por proxy con caché en el volumen.
  resources :ejercicios, only: :index do
    collection { get :ayuda }
    member { get "media/:tipo", action: :media, as: :media, constraints: { tipo: /gif|imagen/ } }
  end

  # Planes y monetización (SDD §09, Fase 5)
  get "mi_plan", to: "planes_personalizados#show", as: :mi_plan
  get "upgrade", to: "planes#index", as: :upgrade

  # Modo sesión (Fase 14.3): pantalla inmersiva del entrenamiento del día,
  # ejercicio por ejercicio y con cronómetro de descanso. La fecha opcional
  # (ISO) permite entrenar un día distinto a hoy.
  get "sesion(/:fecha)", to: "sesiones#show", as: :sesion,
      constraints: { fecha: /\d{4}-\d{2}-\d{2}/ }

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

  # Mesociclo (Fase 14.9): cada semana de la rutina vive en su propio
  # turbo-frame perezoso — lectura autorizada con la policy del plan (show?).
  resources :planes_personalizados, only: [] do
    resources :semanas, only: :show, controller: "gestion_semanas", param: :numero
  end

  namespace :entrenador do
    resources :borradores, only: %i[ index ], controller: "borradores"
    resources :plantillas_comida, only: %i[ create destroy ], controller: "plantillas_comida"
    resources :plantillas_ejercicio, only: %i[ create destroy ], controller: "plantillas_ejercicio"
  end

  # Panel de administración (SDD §09) — protegido por Pundit, no solo por el namespace
  namespace :admin do
    resources :users, only: %i[ index show new create update ] do
      # Antropometría con historial, tomada por el staff (Fase 5.9); editable
      # (Fase 6.11) para corregir cualquier medición pasada, no solo la de hoy.
      resources :mediciones, only: %i[ index new create edit update ]
    end
    resources :membresias, only: %i[ index new create edit update ] do
      resource :renovacion, only: :create, controller: "renovaciones"
    end
    resources :pagos, only: %i[ index edit update destroy ]
    resources :checkins, only: %i[ index create ]
    resources :suscripciones, only: %i[ index new create update ]
    resources :posts, only: %i[ index new create edit update destroy ] do
      post :publicar, on: :member
    end
    resources :novedades, only: %i[ index new create edit update destroy ]
    # Panel de funcionalidades del tenant (Fase 18d): el admin enciende y
    # apaga módulos (blog, novedades, nutrición, ciclo, gamificación…).
    resource :funcionalidades, only: %i[ show update ], controller: "funcionalidades"
  end

  # Portal comercial (SDD §16.6): superadmin gestiona los tenants en
  # comercial/app.ynt.codes (Current.tenant = nil).
  namespace :superadmin do
    resources :tenants
    # Cola de leads del autoservicio (Fase 12a, §17.5): solo listar y marcar
    # atendida — el alta del tenant/usuario sigue siendo manual por :tenants.
    resources :solicitudes_autoservicio, only: %i[ index update ]
  end

  # Comunidad (Fase 8): lectura pública para todo miembro autenticado (SDD §09).
  # Fase 18e: /novedades también es el muro de la comunidad — opt-in de
  # celebrar los logros propios, con consentimiento auditable (patrón ranking).
  resources :novedades, only: :index
  post "novedades/participacion", to: "novedades#participar", as: :novedades_participacion
  delete "novedades/participacion", to: "novedades#retirarse"
  get "blog", to: "blog#index"
  get "blog/:id", to: "blog#show", as: :blog_post

  # Tabla de posiciones del gimnasio (Fase 14.14): leaderboard opt-in sobre la
  # proyección del motor de juego. participacion = consentimiento auditable
  # (14.11) + visible_en_tabla del perfil PROPIO, en una transacción.
  get "ranking", to: "tabla_posiciones#index", as: :ranking
  post "ranking/participacion", to: "tabla_posiciones#participar", as: :ranking_participacion
  delete "ranking/participacion", to: "tabla_posiciones#retirarse"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA: manifest y service worker dinámicos (parametrizados por Negocio/Current.tenant)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
