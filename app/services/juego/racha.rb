module Juego
  # Racha de días de actividad (Fase 14.12): un día cuenta si hubo check-in
  # (`Acceso`) O al menos un ejercicio marcado — ambos caminos encolan
  # OtorgarPuntosJob, que llama aquí. La racha vive en `perfiles_juego`
  # (no hay tabla propia). Idempotente por diseño: el mismo día — o un día
  # anterior a la última fecha, p. ej. marcar un entrenamiento pasado — es
  # no-op y no rompe la racha vigente.
  class Racha
    def self.actualizar!(user, fecha:)
      perfil = PerfilJuego.para(user)
      ultima = perfil.ultima_fecha_racha
      return perfil if ultima && fecha <= ultima

      racha = ultima == fecha - 1.day ? perfil.racha_actual + 1 : 1
      perfil.update!(racha_actual: racha,
                     racha_mejor: [ racha, perfil.racha_mejor ].max,
                     ultima_fecha_racha: fecha)
      perfil
    end
  end
end
