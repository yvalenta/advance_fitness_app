# Seguimiento de entrenamiento (Fase 5.10): el miembro marca Hecho/Pendiente +
# nota por ejercicio del día (hoy o días pasados). Upsert por fecha; responde
# sin cuerpo para que el Stimulus solo confirme el guardado.
# Fase 14.6: el ancla es el uid estable del ejercicio (el índice viaja solo
# como metadato histórico); si el plan es previo al uid, el modelo cae al
# anclaje posicional de siempre.
class RegistrosEntrenamientoController < ApplicationController
  def create
    fecha = fecha_param
    @registro = Current.user.registros_entrenamiento.find_or_initialize_by(fecha: fecha)
    authorize @registro

    if params.key?(:novedad)
      @registro.marcar_novedad!(params[:novedad])
    else
      @registro.marcar!(uid: params[:uid], indice: params[:indice],
                        hecho: ActiveModel::Type::Boolean.new.cast(params[:hecho]),
                        nota: params[:nota], nombre: params[:nombre],
                        dia: dia_de(fecha), plan_id: Current.user.plan_aprobado&.id)
    end
    head :ok
  end

  private
    def fecha_param
      Date.iso8601(params[:fecha].to_s)
    rescue ArgumentError
      Date.current
    end

    # Offset desde el lunes (lunes=0 … domingo=6), el mismo mapeo que
    # PlanPersonalizado::DIAS_OFFSET usa para ubicar el día de la rutina.
    def dia_de(fecha) = (fecha.wday - 1) % 7
end
