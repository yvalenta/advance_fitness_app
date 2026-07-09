# Auto-registro de peso del miembro (Fase 5.9): crea/actualiza su medición del
# día con solo el peso (y grasa % opcional) y alimenta /progreso. Un registro
# por fecha: volver a enviar el mismo día actualiza el peso (no duplica).
class MedicionesController < ApplicationController
  def create
    fecha = params.dig(:medicion, :fecha).presence || Date.current
    @medicion = Current.user.mediciones.find_or_initialize_by(fecha: fecha)
    @medicion.assign_attributes(medicion_params.merge(tomada_por: Current.user))
    authorize @medicion

    if @medicion.save
      redirect_to progreso_path, notice: "Peso registrado."
    else
      redirect_to progreso_path, alert: @medicion.errors.full_messages.to_sentence
    end
  end

  private
    def medicion_params
      params.expect(medicion: [ :peso_kg, :grasa_pct ])
    end
end
