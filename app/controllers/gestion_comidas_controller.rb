# Autosave por comida del editor de plan (SDD Fase 5.6). La edición de
# campos responde JSON; alta/baja responden turbo_stream (Fase 6.9, en vivo
# sin recargar, igual que la rutina). El :id de la comida es su índice en el
# array jsonb plan_nutricional["comidas"].
class GestionComidasController < ApplicationController
  before_action :cargar_plan

  def create
    @plan.agregar_comida!(comida_params)
    render_editor
  end

  def update
    @plan.actualizar_comida!(params[:id].to_i, comida_params)
    render json: cuerpo
  rescue IndexError, KeyError
    render json: { error: "La comida ya no existe." }, status: :not_found
  end

  def destroy
    @plan.eliminar_comida!(params[:id].to_i)
    render_editor
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

    def render_editor
      render turbo_stream: turbo_stream.replace(
        "editor_nutricional",
        partial: "planes_personalizados/editor",
        locals: { plan: @plan, plantillas: PlantillaComida.ordenadas }
      )
    end

    def cargar_plan
      @plan = PlanPersonalizado.find(params[:plan_personalizado_id])
      authorize @plan, :editar?
    end

    def comida_params
      return {} if params[:comida].blank?

      params.expect(comida: PlanPersonalizado::CAMPOS_COMIDA.map(&:to_sym))
    end

    # El total lo recalcula el servidor: es la fuente de verdad del kcal/día.
    def cuerpo
      { comidas: @plan.comidas, kcal_diarias: @plan.plan_nutricional["kcal_diarias"] }
    end
end
