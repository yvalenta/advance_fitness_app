class ApplicationController < ActionController::Base
  include Authentication
  include TenantScoping
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Toda acción de controller de dominio debe autorizar (SDD §08). Los
  # controllers de auth y el dashboard (sin record) quedan exentos.
  SIN_PUNDIT = %w[sessions passwords registrations omniauth_sessions dashboard].freeze
  after_action :verify_authorized, unless: :pundit_exento?

  rescue_from Pundit::NotAuthorizedError do
    redirect_to root_path, alert: "No tienes permiso para realizar esa acción."
  end

  # El pooler de Supabase (modo sesión) tiene un límite duro de 15 conexiones
  # para todo el proyecto; en un pico de tráfico (o con desarrollo apuntando
  # a la misma base vía DEV_DATABASE_URL) una petición puede quedarse sin
  # conexión disponible.
  #
  # OJO: esto NO puede ser un redirect. Un redirect_back/redirect_to lo sigue
  # el navegador solo, y si la página de destino también toca la base (y la
  # base sigue saturada), la siguiente petición vuelve a fallar y redirige de
  # nuevo → loop infinito autoinfligido que satura aún más el pool (visto en
  # producción julio 2026: cientos de peticiones a /objetivo sin interacción
  # del usuario). Por eso se renderiza un cuerpo estático, sin layout (que sí
  # toca la base para el navbar) y sin ningún redirect: el navegador se
  # detiene y el reintento queda en manos del usuario.
  rescue_from ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad do
    respond_to do |format|
      format.turbo_stream { head :service_unavailable }
      format.json { head :service_unavailable }
      format.any { render "errors/servidor_ocupado", layout: false, status: :service_unavailable }
    end
  end

  private
    def pundit_user
      Current.user
    end

    def pundit_exento?
      controller_name.in?(SIN_PUNDIT)
    end
end
