class ApplicationController < ActionController::Base
  include Authentication
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
  # conexión disponible. Sin este rescate, eso era un 500 genérico —
  # ahora es un aviso claro y la acción se puede reintentar sin perder nada.
  rescue_from ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad do
    redirect_back fallback_location: root_path,
                  alert: "El servidor está muy ocupado en este momento. Intenta de nuevo en unos segundos."
  end

  private
    def pundit_user
      Current.user
    end

    def pundit_exento?
      controller_name.in?(SIN_PUNDIT)
    end
end
