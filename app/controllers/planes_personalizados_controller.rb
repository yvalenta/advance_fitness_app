# "Mi plan": el personalizado aprobado, o el free con guías por objetivo
class PlanesPersonalizadosController < ApplicationController
  # wday (0 domingo) → nombre del día como aparece en la rutina (sin acentos)
  DIAS_ES = %w[domingo lunes martes miercoles jueves viernes sabado].freeze

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

    preparar_seguimiento(@plan&.rutina || @plan_basico)
  end

  private
    # Seguimiento de entrenamiento (Fase 5.10): la rutina del día de la fecha
    # elegida (hoy por defecto) + lo que el miembro ya marcó ese día.
    def preparar_seguimiento(rutina)
      return if rutina.blank?

      @fecha_seguimiento = fecha_seguimiento
      @dia_seguimiento = dia_de(rutina, @fecha_seguimiento)
      @registro_seguimiento = Current.user.registros_entrenamiento.find_or_initialize_by(fecha: @fecha_seguimiento)
    end

    def fecha_seguimiento
      Date.iso8601(params[:fecha].to_s)
    rescue ArgumentError
      Date.current
    end

    def dia_de(rutina, fecha)
      nombre = DIAS_ES[fecha.wday]
      Array(rutina["dias"]).find { |dia| dia["dia"].to_s.downcase == nombre }
    end
end
