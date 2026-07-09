# Seguimiento de entrenamiento (Fase 5.10): el miembro marca Hecho/Pendiente +
# nota por ejercicio del día (hoy o días pasados). Upsert por fecha; responde
# sin cuerpo para que el Stimulus solo confirme el guardado.
class RegistrosEntrenamientoController < ApplicationController
  def create
    fecha = fecha_param
    @registro = Current.user.registros_entrenamiento.find_or_initialize_by(fecha: fecha)
    authorize @registro

    @registro.marcar!(params[:indice],
                      hecho: ActiveModel::Type::Boolean.new.cast(params[:hecho]),
                      nota: params[:nota], nombre: params[:nombre])
    head :ok
  end

  private
    def fecha_param
      Date.iso8601(params[:fecha].to_s)
    rescue ArgumentError
      Date.current
    end
end
