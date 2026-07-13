# Autosave del enfoque de un día de la rutina (SDD Fase 5.7b) y aplicación de
# una sesión completa por músculo (Fase 5.11): reemplaza los ejercicios del día
# y refresca solo ese panel vía Turbo Stream.
class GestionDiasController < ApplicationController
  include RenderizaDiaRutina

  def update
    @plan = PlanPersonalizado.find(params[:plan_personalizado_id])
    authorize @plan, :editar_rutina?
    indice = params[:id].to_i

    if (musculo = params.dig(:dia, :sesion_musculo)).present?
      aplicar_sesion(indice, musculo)
    else
      @plan.actualizar_enfoque!(indice, params.dig(:dia, :enfoque).to_s)
      render json: { ok: true }
    end
  rescue IndexError, KeyError, ActiveRecord::RecordNotFound
    render json: { error: "El día ya no existe." }, status: :not_found
  end

  private
    def aplicar_sesion(indice, musculo)
      plantillas = PlantillaEjercicio.ordenadas.where(musculo: musculo).to_a
      @plan.aplicar_sesion!(indice, musculo, plantillas)
      render_dia(indice)
    end
end
