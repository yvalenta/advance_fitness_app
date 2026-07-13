class Admin::MedicionesController < ApplicationController
  before_action :cargar_miembro
  before_action :cargar_medicion, only: %i[ edit update ]

  def index
    authorize Medicion
    @mediciones = @miembro.mediciones.recientes
  end

  def new
    @medicion = @miembro.mediciones.new(fecha: Date.current)
    authorize @medicion
  end

  # Antropometría con historial: la toma el staff (SDD Flujo B / Fase 5.9).
  # Upsert por fecha (Fase 5.13): permite corregir una medición del mismo día
  # (p. ej. el peso rápido del popup de check-in) sin chocar con el índice
  # único user_id+fecha ni duplicar el historial.
  def create
    datos = medicion_params
    fecha = datos[:fecha].presence || Date.current
    @medicion = @miembro.mediciones.find_or_initialize_by(fecha: fecha)
    @medicion.assign_attributes(datos.except(:fecha).merge(tomada_por: Current.user))
    authorize @medicion

    if @medicion.save
      redirect_to admin_user_mediciones_path(@miembro), notice: guardar_y_notificar
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Edición de cualquier medición pasada (Fase 6.11): el staff corrige
  # medidas cargadas con error, no solo las de hoy.
  def edit
  end

  def update
    @medicion.assign_attributes(medicion_params.except(:fecha))

    if @medicion.save
      redirect_to admin_user_mediciones_path(@miembro), notice: guardar_y_notificar
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def cargar_miembro = @miembro = User.find(params[:user_id])

    def cargar_medicion
      @medicion = @miembro.mediciones.find(params[:id])
      authorize @medicion
    end

    def medicion_params
      params.expect(medicion: [ :fecha, :notas, *Medicion::MEDIDAS ])
    end

    # El plan Personalizado (con IA) se arma a partir de la última medición;
    # el sugerido por reglas no usa antropometría, así que no aplica (Fase 6.11).
    def guardar_y_notificar
      quiere_actualizar = ActiveModel::Type::Boolean.new.cast(params[:actualizar_plan])
      plan = @miembro.plan_actual
      return "Medición guardada." unless quiere_actualizar && plan && !plan.reglas?

      plan.marcar_generando!
      GenerarPlanJob.perform_later(plan.id)
      "Medición guardada. El plan se está actualizando con estas medidas."
    end
end
