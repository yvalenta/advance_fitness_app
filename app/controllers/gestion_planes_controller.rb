# Editor de plan compartido por entrenador y admin (SDD Fase 5.6). El entrenador
# llega desde la cola de borradores; el admin, desde Suscripciones. Editar y
# publicar están desacoplados: las comidas se guardan por autosave
# (GestionComidasController) y publicar solo da visibilidad al miembro.
class GestionPlanesController < ApplicationController
  before_action :cargar_plan

  def show
    authorize @plan, :editar?
    @plantillas = PlantillaComida.ordenadas
    @plantillas_ejercicio = PlantillaEjercicio.ordenadas
    @historial = @plan.user.planes_personalizados.order(created_at: :desc)
  end

  def publicar
    authorize @plan, :publicar?
    @plan.publicar!(Current.user)
    redirect_to plan_personalizado_path(@plan),
                notice: "Plan publicado: ya es visible para el miembro."
  end

  # Reintento manual de la generación con IA tras un fallo (SDD Fase 5.7).
  def regenerar
    authorize @plan, :publicar?
    @plan.marcar_generando!
    GenerarPlanJob.perform_later(@plan.id)
    redirect_back fallback_location: entrenador_borradores_path,
                  notice: "Reintentando la generación del plan…"
  end

  # Modo avanzado: pega/ajusta el JSON crudo (rutina o plan nutricional).
  # Las comidas normalmente se editan por autosave (GestionComidasController).
  def update
    authorize @plan, :editar_json?
    @plan.update!(
      rutina: parsear_json(params[:rutina]) || @plan.rutina,
      plan_nutricional: parsear_json(params[:plan_nutricional]) || @plan.plan_nutricional
    )
    redirect_to plan_personalizado_path(@plan), notice: "Plan actualizado."
  rescue JSON::ParserError
    redirect_to plan_personalizado_path(@plan), alert: "El JSON no es válido; revisa la sintaxis."
  end

  private

    # policy_scope + find (tarea 2026-08-31): el find crudo dejaba al staff
    # de A abrir, pisar (JSON crudo), publicar o regenerar el plan de un
    # miembro de B — la policy solo miraba el rol del viewer. Con el Scope,
    # un id ajeno da 404 indistinguible; el permiso fino (editar?/publicar?/
    # editar_json?) lo sigue decidiendo el authorize de cada acción.
    def cargar_plan
      @plan = policy_scope(PlanPersonalizado).find(params[:id])
    end

    def parsear_json(texto)
      texto.present? ? JSON.parse(texto) : nil
    end
end
