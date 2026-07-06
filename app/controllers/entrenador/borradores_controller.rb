class Entrenador::BorradoresController < ApplicationController
  def index
    authorize PlanPersonalizado, :revisar?
    @borradores = PlanPersonalizado.borradores.includes(:user).order(created_at: :asc)
  end

  def show
    @plan = PlanPersonalizado.find(params[:id])
    authorize @plan, :revisar?
  end
end
