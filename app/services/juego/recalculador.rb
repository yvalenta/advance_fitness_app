module Juego
  # Red de seguridad del motor (Fase 14.12): reconstruye la proyección
  # `perfiles_juego` COMPLETA desde el ledger `registros_puntos` (+ logros
  # obtenidos). El ledger es la verdad; la proyección, caché. Idempotente:
  # correrlo N veces da lo mismo. NO toca las preferencias del miembro
  # (visible_en_tabla, apodo), que no son derivables de ningún ledger.
  class Recalculador
    # Tipos cuya fecha cuenta como "día de actividad" para la racha: los
    # mismos dos eventos que disparan OtorgarPuntosJob desde controllers.
    TIPOS_ACTIVIDAD = %w[checkin entrenamiento_completo].freeze

    def self.para(user)
      perfil = PerfilJuego.para(user)
      total = RegistroPunto.where(user: user).sum(:puntos)
      fechas = RegistroPunto.where(user: user, tipo: TIPOS_ACTIVIDAD)
                            .distinct.order(:fecha).pluck(:fecha)
      actual, mejor = rachas_desde(fechas)

      perfil.update!(
        puntos_total: total,
        nivel: PerfilJuego.nivel_para(total),
        racha_actual: actual,
        racha_mejor: mejor,
        ultima_fecha_racha: fechas.last,
        logros_count: LogroObtenido.where(user: user).count
      )
      perfil
    end

    # [racha del último tramo consecutivo, mejor racha histórica], a partir
    # de las fechas de actividad ordenadas y sin duplicados.
    def self.rachas_desde(fechas)
      return [ 0, 0 ] if fechas.empty?

      mejor = actual = 1
      fechas.each_cons(2) do |anterior, fecha|
        actual = fecha == anterior + 1 ? actual + 1 : 1
        mejor = [ mejor, actual ].max
      end
      [ actual, mejor ]
    end
  end
end
