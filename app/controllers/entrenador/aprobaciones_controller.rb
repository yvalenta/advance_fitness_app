class Entrenador::AprobacionesController < ApplicationController
  # Aprueba el borrador; el entrenador puede ajustar el JSONB antes (SDD flujo B)
  def create
    plan = PlanPersonalizado.find(params[:borrador_id])
    authorize plan, :aprobar?

    plan.aprobar!(
      Current.user,
      rutina: parsear_json(params[:rutina]),
      plan_nutricional: parsear_json(params[:plan_nutricional])
    )
    redirect_to entrenador_borradores_path, notice: "Plan aprobado: ya es visible para el miembro."
  rescue JSON::ParserError
    redirect_to entrenador_borrador_path(params[:borrador_id]),
                alert: "El JSON ajustado no es válido; revisa la sintaxis."
  end

  private

    def parsear_json(texto)
      texto.present? ? JSON.parse(texto) : nil
    end
end
