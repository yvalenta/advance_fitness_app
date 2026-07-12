class Admin::MedicionesController < ApplicationController
  before_action :cargar_miembro

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
      redirect_to admin_user_mediciones_path(@miembro), notice: "Medición registrada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def cargar_miembro = @miembro = User.find(params[:user_id])

    def medicion_params
      params.expect(medicion: [ :fecha, :notas, *Medicion::MEDIDAS ])
    end
end
