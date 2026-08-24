# Reprogramar un día (Fase 19e): siempre el propio plan aprobado del
# miembro, nunca un plan_id del cliente — mismo criterio que
# RegistrosEntrenamientoController/CiclosMenstrualesController.
class ReprogramacionesDiaController < ApplicationController
  def create
    plan = Current.user.plan_aprobado
    if plan.nil?
      skip_authorization
      redirect_to sesion_path, alert: "No tienes un plan activo." and return
    end

    fecha_original = Date.iso8601(params[:fecha_original].to_s)
    fecha_destino = Date.iso8601(params[:fecha_destino].to_s)

    reprogramacion = plan.reprogramaciones_dia.find_or_initialize_by(fecha_original: fecha_original)
    authorize reprogramacion
    reprogramacion.fecha_destino = fecha_destino

    if reprogramacion.save
      redirect_to sesion_path(fecha_original.iso8601),
        notice: "Entrenamiento movido a #{l fecha_destino, format: :long}."
    else
      redirect_to sesion_path(fecha_original.iso8601), alert: reprogramacion.errors.full_messages.to_sentence
    end
  rescue ArgumentError
    skip_authorization
    redirect_to sesion_path, alert: "Fecha inválida."
  end

  def destroy
    plan = Current.user.plan_aprobado
    if plan.nil?
      skip_authorization
      redirect_to sesion_path, alert: "No tienes un plan activo." and return
    end

    reprogramacion = plan.reprogramaciones_dia.find(params[:id])
    authorize reprogramacion
    origen = reprogramacion.fecha_original
    reprogramacion.destroy!
    redirect_to sesion_path(origen.iso8601), notice: "Reprogramación cancelada."
  end
end
