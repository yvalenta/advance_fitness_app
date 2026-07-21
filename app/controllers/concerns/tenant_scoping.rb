# Resuelve el tenant activo desde el subdominio del request y lo expone en
# `Current.tenant` para el resto de la petición (SDD §16.6, row-level
# multi-tenancy por subdominio):
#
#   {slug}.ynt.codes          → tenant con ese slug (o 404 si no existe/inactivo)
#   comercial.ynt.codes,
#   app.ynt.codes             → modo global (Current.tenant = nil): portal
#                               comercial para superadmin y comercializador.
#   advance-fitness-app.ynt.codes,
#   apex/www.ynt.codes        → tenant "advance-fitness" (back-compat mientras
#                               no exista el wildcard DNS + TLS + túnel).
#
# Se corre antes de `require_authentication` para que la página de login ya
# tenga el branding correcto del tenant. Tras autenticar, se verifica que el
# usuario pertenece al tenant del subdominio (defensa en profundidad frente a
# una cookie robada o un miembro que pega el subdominio de otro cliente).
module TenantScoping
  extend ActiveSupport::Concern

  BACK_COMPAT_ADVANCE_FITNESS = %w[www advance-fitness-app].freeze
  SUBDOMINIOS_COMERCIALES = %w[comercial app].freeze
  SUBDOMINIOS_LANDING = %w[join unete].freeze

  included do
    # `prepend_before_action` para correr ANTES de `require_authentication`
    # (Authentication está incluido antes que TenantScoping): la página de
    # login necesita el branding correcto del tenant.
    prepend_before_action :resolver_tenant
    before_action :verificar_pertenencia_al_tenant, if: :usuario_autenticado?
  end

  private
    def resolver_tenant
      sub = request.subdomain.to_s.downcase

      if sub.blank? || BACK_COMPAT_ADVANCE_FITNESS.include?(sub)
        Current.tenant = Tenant.find_by(slug: "advance-fitness")
      elsif SUBDOMINIOS_COMERCIALES.include?(sub)
        Current.tenant = nil
      elsif SUBDOMINIOS_LANDING.include?(sub)
        # Tenant resuelto desde el primer segmento del path: /promo-fitness-2026
        slug = request.path.split("/").reject(&:blank?).first.to_s.downcase
        Current.landing_slug = slug
        Current.tenant = Tenant.activos.find_by(slug: slug) if slug.present?
        # Sin 404 aquí: Landing::CampañasController maneja el not-found
      else
        tenant = Tenant.activos.find_by(slug: sub)
        return tenant_no_encontrado if tenant.nil?
        Current.tenant = tenant
      end
    end

    def tenant_no_encontrado
      render "errors/tenant_no_encontrado", layout: false, status: :not_found
    end

    # superadmin ve todo y opera en el portal comercial; comercializador vive
    # en el portal comercial. Los demás roles deben coincidir con el tenant
    # del subdominio.
    def verificar_pertenencia_al_tenant
      return if Current.user.superadmin?

      if Current.tenant.nil?
        return if Current.user.comercializador?
        terminate_session
        redirect_to new_session_url, alert: "Inicia sesión desde el subdominio de tu gimnasio."
      elsif Current.user.tenant_id != Current.tenant.id
        terminate_session
        redirect_to new_session_url, alert: "No tienes acceso a este espacio."
      end
    end

    def usuario_autenticado?
      Current.user.present?
    end
end
