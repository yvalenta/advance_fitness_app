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
      preparar_edicion_rutina
    else
      skip_authorization # vista free: solo contenido estático del propio usuario
    end
  end

  private
    # La rutina de CUALQUIER plan publicado propio es editable por su dueño
    # (Fase 5.12: sugerido o de IA); el editor inline necesita las plantillas
    # del popup. La nutrición del plan de IA sigue siendo solo del staff.
    def preparar_edicion_rutina
      @editable = PlanPersonalizadoPolicy.new(Current.user, @plan).editar_rutina?
      @plantillas_ejercicio = PlantillaEjercicio.ordenadas if @editable
    end
end
