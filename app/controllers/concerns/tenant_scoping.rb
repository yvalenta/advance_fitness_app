# Resuelve el tenant activo desde el subdominio del request y lo expone en
# `Current.tenant` para el resto de la petición (SDD §16.6, row-level
# multi-tenancy por subdominio):
#
#   {slug}.ynt.codes          → tenant con ese slug (o 404 si no existe/inactivo)
#   comercial.ynt.codes,
#   app.ynt.codes             → modo global (Current.tenant = nil): portal
#                               comercial para superadmin y comercializador.
#   trainer.ynt.codes,
#   entrena.ynt.codes         → modo global (Current.tenant = nil): landing de
#                               autoservicio (Fase 12b, §17.5), una por audiencia.
#   advance-fitness-app.ynt.codes,
#   apex/www.ynt.codes        → tenant "advance-fitness" (back-compat mientras
#                               no exista el wildcard DNS + TLS + túnel).
#
# Se corre antes de `require_authentication` para que la página de login ya
# tenga el branding correcto del tenant. Tras autenticar, se verifica que el
# usuario tiene PUESTO en el tenant del subdominio y que su cuenta está
# estacionada ahí (defensa en profundidad frente a una cookie robada, un
# miembro que pega el subdominio de otro cliente, o un puesto revocado con
# la sesión todavía viva).
module TenantScoping
  extend ActiveSupport::Concern

  BACK_COMPAT_ADVANCE_FITNESS = %w[www advance-fitness-app].freeze
  SUBDOMINIOS_COMERCIALES = %w[comercial app].freeze
  SUBDOMINIOS_LANDING = %w[join unete].freeze
  # Autoservicio (Fase 12b, §17.5): landings públicas de un solo dueño (no de
  # tenant) — igual que el portal comercial, Current.tenant queda nil.
  SUBDOMINIOS_AUTOSERVICIO = %w[trainer entrena].freeze

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
      elsif SUBDOMINIOS_COMERCIALES.include?(sub) || SUBDOMINIOS_AUTOSERVICIO.include?(sub)
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
    # en el portal comercial. Para los demás roles la pertenencia sale del
    # PUESTO (tarea 2026-08-31): la verdad de "quién pertenece a este
    # gimnasio" es la tabla `puestos`, no la cache `users.tenant_id`. Dos
    # consecuencias deliberadas:
    #
    #   · REVOCACIÓN INMEDIATA: si un admin borra el puesto, la sesión viva
    #     muere en el siguiente request — antes, la cache seguía diciendo que
    #     el usuario pertenecía y la sesión sobrevivía a la revocación.
    #   · COHERENCIA DE LA CACHE: con puesto acá pero la cuenta ESTACIONADA
    #     en otra organización (users.tenant_id apunta a otro tenant), las 30
    #     policies leerían el rol y el tenant del otro gimnasio bajo el
    #     branding de este. Ese estado solo lo resuelve el embudo del cambio
    #     de organización (User#estacionar_en! + pase firmado); acá se corta
    #     la sesión en vez de responder incoherente.
    #
    # UNA query por request, memoizada en `Current.puesto` — todo lo que
    # necesite el puesto vigente (navbar, selector) lee el atributo, no
    # repite la query (pooler de producción: 15 conexiones).
    def verificar_pertenencia_al_tenant
      return auditar_visita_de_superadmin if Current.user.superadmin?

      if Current.tenant.nil?
        return if Current.user.comercializador?
        terminate_session
        redirect_to new_session_url, alert: "Inicia sesión desde el subdominio de tu gimnasio."
      else
        Current.puesto = Puesto.find_by(user_id: Current.user.id, tenant_id: Current.tenant.id)
        if Current.puesto.nil?
          terminate_session
          redirect_to new_session_url, alert: "Tu cuenta pertenece a otro gimnasio. Crea una cuenta aquí o inicia sesión en tu espacio."
        elsif Current.user.tenant_id != Current.tenant.id
          terminate_session
          redirect_to new_session_url, alert: "Tu cuenta está activa en otra organización. Inicia sesión aquí para cambiarte a este gimnasio."
        end
      end
    end

    # superadmin entrando a un tenant ajeno TAMBIÉN deja rastro (tarea
    # 2026-08-31, punto 4): misma tabla append-only del pase firmado, pero
    # sin token_digest — no hubo pase, entra por su rol — y con de_tenant
    # nil (viene del portal comercial, que no es un tenant). Su semántica de
    # siempre no cambia: pasa sin puesto y sin cortes; esto solo ESCRIBE.
    #
    # Una fila por (sesión de navegador, tenant) y no por request: el flag
    # vive en la session cookie de Rails — host-only como todo acá, así que
    # cada subdominio audita su propia entrada.
    def auditar_visita_de_superadmin
      return if Current.tenant.nil?
      return if session[:superadmin_tenant_auditado] == Current.tenant.id

      CambioOrganizacion.create!(
        user: Current.user, de_tenant: nil, a_tenant: Current.tenant,
        ip: request.remote_ip, user_agent: request.user_agent
      )
      session[:superadmin_tenant_auditado] = Current.tenant.id
    end

    def usuario_autenticado?
      Current.user.present?
    end
end
