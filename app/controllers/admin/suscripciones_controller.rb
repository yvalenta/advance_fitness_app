class Admin::SuscripcionesController < ApplicationController
  def index
    authorize Suscripcion, :index?
    @suscripciones = Suscripcion.includes(:user, :plan).order(created_at: :desc)
  end

  def new
    authorize Suscripcion, :create?
    @suscripcion = Suscripcion.new(fecha_inicio: Date.current)
  end

  # Alta del plan personalizado pagado en recepción (SDD flujo B paso 2):
  # al crearse se encola GenerarPlanJob — el request no espera a la IA.
  def create
    authorize Suscripcion, :create?
    datos = params.expect(suscripcion: %i[user_id fecha_inicio fecha_fin])
    @suscripcion = Suscripcion.new(datos.merge(plan: Plan.personalizado, estado: "activa"))

    if @suscripcion.save
      encolar_generacion(@suscripcion.user)
      redirect_to admin_suscripciones_path,
                  notice: "Suscripción creada. El plan con IA se está generando y quedará en revisión del entrenador."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Única transición permitida desde el panel: cancelar
  def update
    suscripcion = Suscripcion.find(params[:id])
    authorize suscripcion, :update?
    suscripcion.cancelar!
    redirect_to admin_suscripciones_path, notice: "Suscripción cancelada."
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
end
