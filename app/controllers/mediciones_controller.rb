# Auto-registro de peso del miembro (Fase 5.9): crea/actualiza su medición de
# una fecha (hoy por defecto) con solo el peso (y grasa % opcional). Un
# registro por fecha: volver a enviar la misma fecha corrige el peso, sin
# duplicar ni tocar el resto de la antropometría de ese día (Fase 5.12: el
# miembro también agrega pesos pasados y corrige los ya registrados).
class MedicionesController < ApplicationController
  def create
    # Autoriza sobre una instancia propia primero: todo return posterior deja
    # satisfecho verify_authorized (SDD §08), incluida la salida temprana por
    # fecha futura.
    authorize Current.user.mediciones.new, :create?
    fecha = fecha_valida(params.dig(:medicion, :fecha))
    if fecha > Date.current
      return redirect_to progreso_path, alert: "No puedes registrar un peso futuro."
    end

    @medicion = Current.user.mediciones.find_or_initialize_by(fecha: fecha)
    @medicion.assign_attributes(medicion_params.merge(tomada_por: Current.user))

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

    def fecha_valida(crudo)
      Date.iso8601(crudo.to_s)
    rescue ArgumentError
      Date.current
    end
end
