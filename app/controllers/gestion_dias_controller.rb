# Autosave del enfoque de un día de la rutina (SDD Fase 5.7b).
class GestionDiasController < ApplicationController
  def update
    @plan = PlanPersonalizado.find(params[:plan_personalizado_id])
    authorize @plan, :editar?
    @plan.actualizar_enfoque!(params[:id].to_i, params.dig(:dia, :enfoque).to_s)
    render json: { ok: true }
  rescue IndexError, KeyError
    render json: { error: "El día ya no existe." }, status: :not_found
  end
end
