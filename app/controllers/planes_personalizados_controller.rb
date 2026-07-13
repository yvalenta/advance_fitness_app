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
    else
      skip_authorization # vista free: solo contenido estático del propio usuario
    end
  end
end
