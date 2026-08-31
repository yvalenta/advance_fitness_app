class Entrenador::BorradoresController < ApplicationController
  # Cola de revisión: los borradores generados por IA pendientes de publicar.
  # Cada fila abre el editor compartido (GestionPlanesController).
  def index
    authorize PlanPersonalizado, :revisar?
    # policy_scope (tarea 2026-08-31): la cola es la del gimnasio del
    # entrenador — sin el Scope listaba borradores de miembros de CUALQUIER
    # tenant (nombre incluido vía includes(:user)).
    @pendientes = policy_scope(PlanPersonalizado).pendientes.includes(:user).order(created_at: :asc)
  end
end
