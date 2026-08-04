# Seguimiento de entrenamiento (Fase 5.10): el miembro marca Hecho/Pendiente +
# nota por ejercicio del día (hoy o días pasados). Upsert por fecha; responde
# sin cuerpo para que el Stimulus solo confirme el guardado.
class RegistrosEntrenamientoController < ApplicationController
  def create
    fecha = fecha_param
    @registro = Current.user.registros_entrenamiento.find_or_initialize_by(fecha: fecha)
    authorize @registro

    if params.key?(:novedad)
      @registro.marcar_novedad!(params[:novedad])
    else
      hecho = ActiveModel::Type::Boolean.new.cast(params[:hecho])
      primer_hecho_del_dia = hecho && !@registro.algun_ejercicio_hecho?
      @registro.marcar!(params[:indice], hecho: hecho,
                        nota: params[:nota], nombre: params[:nombre])
      # Motor de juego (Fase 14.12): UN job por día de entrenamiento — se
      # encola solo con el PRIMER ejercicio hecho del día, no por cada
      # ejercicio (pooler de 15 conexiones). El registro del día es el
      # origen, así que la constraint única del ledger garantiza un solo
      # otorgamiento por día aunque el flujo se repita.
      if primer_hecho_del_dia
        OtorgarPuntosJob.perform_later(Current.user.id, tipo: "entrenamiento_completo",
                                       fecha: fecha, origen_gid: @registro.to_global_id.to_s)
      end
    end
    head :ok
  end

  private
    def fecha_param
      Date.iso8601(params[:fecha].to_s)
    rescue ArgumentError
      Date.current
    end
end
