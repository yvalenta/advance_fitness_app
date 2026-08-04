# Dashboard "Hoy" del miembro (Fase 14.5): qué toca entrenar hoy, racha,
# calorías y membresía. Número de queries CONSTANTE (lo fija el spec): todo
# lo derivado de la rutina y del registro del día se resuelve en Ruby sobre
# los jsonb ya cargados — la vista tiene prohibido consultar.
class DashboardController < ApplicationController
  def show
    @membresia = Current.user.membresia
    @objetivo = Current.user.objetivo_activo
    @registro_hoy = Current.user.registros_calorias.find_by(fecha: Date.current)
    # Perezoso y SIN escribir: el perfil real lo crea el motor de juego
    # (Fase 14.12) al otorgar puntos; aquí un new con defaults (racha 0)
    # basta para pintar la card sin sembrar filas por solo mirar el panel.
    @perfil_juego = PerfilJuego.find_or_initialize_by(user: Current.user)
    @plan = Current.user.plan_aprobado
    @dia_hoy = dia_de_hoy
    @entrenamiento_hoy = Current.user.registros_entrenamiento.find_by(fecha: Date.current)
    @hechos_hoy = @entrenamiento_hoy&.conteo_hechos.to_i
  end

  private
    # Día de la rutina que corresponde a hoy, por nombre del día de la semana
    # (DIAS_OFFSET, Fase 5.10). La rutina v2 (Fase 14.6) usa el mismo array
    # "dias" que la v1, así que no hay bifurcación. Domingo (o cualquier día
    # sin sesión) devuelve nil → la vista muestra descanso.
    def dia_de_hoy
      return unless @plan

      offset_hoy = Date.current.cwday - 1
      @plan.dias.find { |dia| PlanPersonalizado::DIAS_OFFSET[dia["dia"].to_s.downcase] == offset_hoy }
    end
end
