class Admin::SuscripcionesController < ApplicationController
  def index
    authorize Suscripcion, :index?
    @q = params[:q].to_s.strip
    # Aislado por `tenant_id` propio (SDD §16.7) vía policy_scope: antes este
    # listado armaba el join a mano — justo el patrón que el ADR elimina.
    @suscripciones = policy_scope(Suscripcion).includes(:user, :plan).order(created_at: :desc)
    if @q.present?
      @suscripciones = @suscripciones.joins(:user)
        .where("users.nombre ILIKE :q OR users.email_address ILIKE :q", q: "%#{User.sanitize_sql_like(@q)}%")
    end
    @suscripciones = @suscripciones.page(params[:page]).per(25)
  end

  def new
    authorize Suscripcion, :create?
    @suscripcion = Suscripcion.new(fecha_inicio: Date.current)
    @medicion = Medicion.new(fecha: Date.current)
    @miembros_disponibles = miembros_sin_suscripcion_activa
  end

  # Alta del plan personalizado pagado en recepción (SDD flujo B paso 2): se
  # toma la medición antropométrica (obligatoria) y, tras guardarla junto con la
  # suscripción, se encola GenerarPlanJob — el request no espera a la IA.
  def create
    authorize Suscripcion, :create?
    datos = params.expect(suscripcion: %i[user_id fecha_inicio fecha_fin])
    medicion_datos = medicion_params
    @miembros_disponibles = miembros_sin_suscripcion_activa

    # Verificar que el usuario pertenece al tenant y es miembro
    unless miembros_del_tenant.exists?(id: datos[:user_id])
      @suscripcion = Suscripcion.new(datos)
      @medicion = Medicion.new(medicion_datos)
      @suscripcion.errors.add(:user_id, "no es un miembro válido de este gimnasio")
      return render :new, status: :unprocessable_entity
    end

    @suscripcion = Suscripcion.new(datos.merge(plan: Plan.personalizado, estado: "activa"))
    # Upsert por fecha (como el resto de flujos de medición, Fase 5.12/5.13):
    # reintentar el alta el mismo día corrige la medición en vez de chocar
    # con el índice único user_id+fecha y abortar toda la suscripción.
    @medicion = Medicion.find_or_initialize_by(user_id: datos[:user_id], fecha: medicion_datos[:fecha].presence || Date.current)
    @medicion.assign_attributes(medicion_datos.except(:fecha).merge(tomada_por: Current.user))

    Suscripcion.transaction do
      @suscripcion.save!
      @medicion.user = @suscripcion.user
      @medicion.save!
      asegurar_membresia(@suscripcion)
    end

    encolar_generacion(@suscripcion.user)
    redirect_to admin_suscripciones_path,
                notice: "Suscripción creada con su medición y membresía incluida. El plan con IA se está generando y quedará en revisión del entrenador."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  # Dos transiciones desde el panel: cancelar (desde el listado), o cambiar
  # el nivel de análisis IA (Fase 12, asignación manual por staff sin
  # pasarela nueva — se dispara desde la ficha del miembro, no el listado,
  # y responde turbo_stream para no salir de esa página).
  def update
    # policy_scope + find (tarea 2026-08-31): el find crudo dejaba al admin
    # de un gimnasio cancelar o cambiar el tier de suscripciones del otro
    # por ID. Con el scope, el ID ajeno es RecordNotFound = 404.
    suscripcion = policy_scope(Suscripcion).find(params[:id])
    authorize suscripcion, :update?

    if params[:analisis_tier].present?
      suscripcion.update!(analisis_tier: params[:analisis_tier])
      user = suscripcion.user
      render turbo_stream: turbo_stream.replace(
        "panel_analisis_#{user.id}",
        partial: "admin/users/panel_analisis",
        locals: { user: user, registro_reciente: user.registros_entrenamiento.order(fecha: :desc).first }
      )
    else
      suscripcion.cancelar!
      redirect_to admin_suscripciones_path, notice: "Suscripción cancelada."
    end
  end

  private

    # Crea el plan en "generando" (visible en la cola del entrenador con su
    # estado) y encola el job. Evita duplicar si ya hay uno en curso/revisión.
    def encolar_generacion(user)
      return if user.planes_personalizados.pendientes.exists?

      plan = user.planes_personalizados.create!(estado: "generando", generado_por: "ia",
                                                rutina: {}, plan_nutricional: {})
      GenerarPlanJob.perform_later(plan.id)
    end

    # Enumeración por PUESTOS del tenant (tarea 2026-08-31) — el rol que
    # filtra es el DEL PUESTO acá, no la cache users.rol — Y ADEMÁS
    # estacionado acá (`users.tenant_id`): esta lista alimenta la CREACIÓN de
    # dinero, y una suscripción hereda el tenant de la cache del dueño
    # (TenantDesnormalizado) — ofrecer a alguien estacionado en otro gimnasio
    # crearía una fila anclada ALLÁ, invisible en la caja de acá. Hasta el
    # épico del dinero multi-gimnasio: el dinero se opera donde la cuenta
    # está estacionada; para ENCONTRAR a la persona está la lista de usuarios,
    # que sí enumera por puestos a secas.
    def miembros_del_tenant
      User.joins(:puestos).where(puestos: { tenant_id: Current.user.tenant_id,
                                            rol: %w[miembro entrenador] })
          .where(tenant_id: Current.user.tenant_id)
    end

    def miembros_sin_suscripcion_activa
      miembros_del_tenant.where.not(id: Suscripcion.activas.select(:user_id)).order(:nombre)
    end

    def medicion_params
      params.expect(medicion: [ :fecha, :notas, *Medicion::MEDIDAS ])
    end

    # La membresía va incluida con el plan personalizado (SDD Flujo B, 5.11):
    # sin membresía se crea activa; vencida/suspendida se reactiva y extiende.
    # Sin pago aparte: el precio del plan la cubre.
    def asegurar_membresia(suscripcion)
      membresia = suscripcion.user.membresia
      inicio = suscripcion.fecha_inicio || Date.current

      if membresia.nil?
        Membresia.create!(user: suscripcion.user, estado: "activa", fecha_inicio: inicio,
                          fecha_vencimiento: inicio + Membresia.duracion)
      elsif !membresia.activa?
        membresia.update!(estado: "activa", fecha_inicio: Date.current,
                          fecha_vencimiento: Date.current + Membresia.duracion)
      end
    end
end
