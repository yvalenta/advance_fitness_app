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
      @anteriores = anteriores_por_ejercicio
    else
      skip_authorization # vista free: solo contenido estático del propio usuario
    end
  end

  private
    # "La vez pasada" (Fase 14.2): hash {ejercicio_id => última serie} en UNA
    # query para toda la rutina — el partial tiene prohibido consultar (N+1).
    def anteriores_por_ejercicio
      return {} unless @plan.user_id == Current.user.id

      ids = @plan.dias.flat_map { |dia| Array(dia["ejercicios"]).map { |ejercicio| ejercicio["ejercicio_id"] } }.compact
      DetalleEntrenamiento.ultimos_por_ejercicio(Current.user, ids)
    end
end
