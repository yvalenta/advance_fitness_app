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
  def create
    @medicion = @miembro.mediciones.new(medicion_params.merge(tomada_por: Current.user))
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
