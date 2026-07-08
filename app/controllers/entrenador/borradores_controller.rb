class Entrenador::BorradoresController < ApplicationController
  # Cola de revisión: los borradores generados por IA pendientes de publicar.
  # Cada fila abre el editor compartido (GestionPlanesController).
  def index
    authorize PlanPersonalizado, :revisar?
    @borradores = PlanPersonalizado.borradores.includes(:user).order(created_at: :asc)
  end
end
