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
      # Plan básico incluido con la membresía activa (SDD Fase 5.9): reglas, sin IA.
      if !Current.user.premium? && Current.user.membresia&.activa?
        @plan_basico = GeneradorPlanBasico.para(Current.user)
      end
    end
  end
end
