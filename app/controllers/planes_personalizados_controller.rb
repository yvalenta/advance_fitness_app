# "Mi plan": el personalizado aprobado, o el free con guías por objetivo
class PlanesPersonalizadosController < ApplicationController
  def show
    @plan = Current.user.plan_aprobado
    @objetivo = Current.user.objetivo_activo
    @pendiente = Current.user.premium? && @plan.nil?

    if @plan
      authorize @plan, :show?
    else
      skip_authorization # vista free: solo contenido estático del propio usuario
    end
  end
end
