# El pase firmado del cambio de organización (tarea 2026-08-31): el puente
# entre subdominios SIN compartir cookie. La cookie de sesión es host-only a
# propósito — JAMÁS `domain: ".ynt.codes"`: el apex aloja otras apps de la
# casa y filtrarles la sesión sería un incidente. Lo único que cruza de un
# subdominio al otro es un pase firmado de 15 segundos y UN solo uso.
#
# Flujo (origen → destino):
#   1. #create corre en el subdominio ORIGEN, autenticado: valida que la
#      cuenta tenga PUESTO en el tenant destino, emite el pase
#      (signed_id con purpose fijo) y redirige el navegador a
#      https://{slug-destino}.{dominio}/cambio_organizacion?token={pase}.
#   2. #show corre en el subdominio DESTINO, SIN sesión previa (la cookie del
#      origen es host-only y no llega hasta acá): canjea el pase, reclama su
#      digest contra el índice único (un solo uso), re-estaciona la cache
#      (User#estacionar_en!), abre una sesión NUEVA de este host y deja la
#      fila de auditoría en cambios_organizacion.
#
# Igual que sessions/passwords, este controller vive en SIN_PUNDIT
# (ApplicationController): no hay record que autorizar — #show ni siquiera
# tiene usuario autenticado cuando arranca. La autorización REAL es el
# puesto del par (user, tenant destino), validado en los DOS extremos.
class CambiosOrganizacionController < ApplicationController
  # El canje llega al destino sin cookie: no puede exigir autenticación.
  allow_unauthenticated_access only: :show
  # Mismo freno que el login (SessionsController#create): el canje es una
  # puerta de entrada sin sesión y no se deja adivinar pases a fuerza bruta.
  rate_limit to: 10, within: 3.minutes, only: :show, with: -> { redirect_to new_session_path, alert: "Intenta de nuevo más tarde." }

  # La vida del pase: lo que tarda UN redirect entre subdominios, no más.
  # 15 s y no 30 (tarea 2026-08-31): el navegador sigue el redirect en menos
  # de un segundo — 15 s ya es holgura para una red lenta, y achica a la
  # mitad la ventana en la que un token robado serviría.
  #
  # RESIDUO ACEPTADO de llevar el pase en la URL: queda en el historial del
  # navegador (y podría viajar en un Referer si el destino redirigiera afuera,
  # que no lo hace: va a root_path). Explotable solo DENTRO de la ventana y
  # solo si el canje legítimo no llegó a consumirlo — el un-solo-uso (índice
  # único sobre token_digest) mata el token en el canje. Los logs ya no lo
  # ven: `filter_parameters` cubre el request del destino y `filter_redirect`
  # (config/initializers/filter_parameter_logging.rb) la línea "Redirected
  # to" del origen. La alternativa sin URL (POST cross-subdominio) rompería
  # el flujo de UN redirect sin cookie compartida.
  VALIDEZ_DEL_PASE = 15.seconds
  PROPOSITO = :cambio_organizacion

  # ORIGEN: emite el pase y manda el navegador al subdominio destino.
  def create
    destino = Tenant.activos.find_by(id: params[:tenant_id])
    if destino.nil? || !Current.user.puestos.exists?(tenant_id: destino.id)
      return redirect_to root_path, alert: "No tienes un puesto en esa organización."
    end

    token = Current.user.signed_id(purpose: PROPOSITO, expires_in: VALIDEZ_DEL_PASE)
    # El destino vive en otro host: mismo dominio, protocolo y puerto del
    # request (en test es example.com, en dev puede ser lvh.me:3000 — no se
    # fija nada acá), solo cambia el subdominio por el slug del destino.
    redirect_to cambio_organizacion_url(host: "#{destino.slug}.#{request.domain}", token: token),
                allow_other_host: true
  end

  # DESTINO: canjea el pase. TODO fallo — token vencido, purpose ajeno, pase
  # reusado, cuenta sin puesto acá — termina en el MISMO redirect al login
  # sin sesión creada y sin detallar el porqué: a quien trae un pase malo no
  # se le cuenta qué parte falló.
  def show
    user = User.find_signed(params[:token], purpose: PROPOSITO)
    return rechazar if user.nil? || Current.tenant.nil?
    return rechazar unless user.puestos.exists?(tenant_id: Current.tenant.id)

    # `de` = donde la cuenta estaba ESTACIONADA antes del salto (la cache
    # users.tenant_id) — verificable acá mismo, sin confiar en nada más que
    # venga del navegador.
    canjear(user, de_tenant_id: user.tenant_id)
    redirect_to root_path
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # RecordNotUnique = pase REUSADO (el digest chocó contra el índice único
    # de cambios_organizacion — el candado del UN solo uso vive en la base).
    # RecordInvalid = la divergencia de email documentada en estacionar_en!.
    # La transacción ya deshizo todo: ni log, ni cache movida, ni sesión.
    rechazar
  end

  private
    def canjear(user, de_tenant_id:)
      ApplicationRecord.transaction do
        # El log va PRIMERO: reclama el token_digest contra el índice único
        # antes de mover nada — dos canjes simultáneos del mismo pase pelean
        # acá y solo uno sobrevive.
        CambioOrganizacion.create!(
          user: user,
          de_tenant_id: de_tenant_id,
          a_tenant: Current.tenant,
          ip: request.remote_ip,
          user_agent: request.user_agent,
          token_digest: Digest::SHA256.hexdigest(params[:token].to_s)
        )
        user.estacionar_en!(Current.tenant)
        # Sesión NUEVA con la cookie host-only de ESTE subdominio; va al
        # final: si algo de arriba revienta, ninguna cookie quedó puesta.
        start_new_session_for user
      end
    end

    def rechazar
      redirect_to new_session_path, alert: "El enlace ya no es válido. Inicia sesión para continuar."
    end
end
