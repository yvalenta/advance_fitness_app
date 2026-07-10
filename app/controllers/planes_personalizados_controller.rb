# "Mi plan": el personalizado aprobado, o el free con guías por objetivo
class PlanesPersonalizadosController < ApplicationController
  def show
    # Miembros con membresía activa que aún no tienen plan: se crea el sugerido
    # aquí mismo si ya hay objetivo (idempotente); si no, se le pregunta la meta.
    PlanPersonalizado.asegurar_sugerido!(Current.user)

    @plan = Current.user.plan_aprobado
    @objetivo = Current.user.objetivo_activo
    @pendiente = Current.user.premium? && @plan.nil?
    @falta_meta = @plan.nil? && @objetivo.nil? && Current.user.membresia&.activa?

    if @plan
      authorize @plan, :show?
      preparar_edicion_sugerido
    else
      skip_authorization # vista free: solo contenido estático del propio usuario
    end
  end

  private
    # El plan sugerido (reglas) es editable por su dueño (Fase 5.11): el editor
    # inline necesita las plantillas del popup.
    def preparar_edicion_sugerido
      return unless @plan.reglas?

      @editable = PlanPersonalizadoPolicy.new(Current.user, @plan).editar?
      @plantillas_ejercicio = PlantillaEjercicio.ordenadas if @editable
    end
end
