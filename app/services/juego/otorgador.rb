module Juego
  # Único punto de escritura del ledger `registros_puntos` (Fase 14.12).
  # Sin acceso a Current: recibe todo por parámetro. JAMÁS se llama desde
  # callbacks de modelos de dominio (el check-in es sensible a latencia y
  # `demo:sembrar` dispararía miles de puntos): los controllers encolan
  # OtorgarPuntosJob y el job llama aquí.
  class Otorgador
    # Puntos por defecto por tipo. Los de check-in valen más que un
    # auto-reporte porque el gimnasio los verifica en recepción; `logro` y
    # `ajuste_manual` no tienen default: los puntos vienen del catálogo o
    # del staff, siempre explícitos.
    PUNTOS = {
      "checkin" => 10,
      "entrenamiento_completo" => 15,
      "racha_semanal" => 25,
      "pr" => 30
    }.freeze

    # Inserta en el ledger y actualiza la proyección en la misma pasada.
    # Idempotente frente a los reintentos de ApplicationJob (retry_on
    # ConnectionNotEstablished, 5 intentos): la constraint única parcial
    # (user, tipo, origen) convierte el duplicado en RecordNotUnique →
    # no-op que devuelve nil.
    def self.otorgar!(user, tipo:, puntos: nil, origen: nil, fecha: Date.current, creado_por: nil)
      puntos ||= PUNTOS[tipo]
      raise ArgumentError, "puntos es obligatorio para el tipo #{tipo}" if puntos.nil?

      registro = RegistroPunto.create!(user: user, tipo: tipo, puntos: puntos,
                                       fecha: fecha, origen: origen, creado_por: creado_por)
      actualizar_proyeccion(user)
      registro
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    # puntos_total se RESUMA desde el ledger, no se incrementa: así la
    # proyección queda correcta aunque esta pasada corra dos veces.
    def self.actualizar_proyeccion(user)
      perfil = PerfilJuego.para(user)
      total = RegistroPunto.where(user: user).sum(:puntos)
      perfil.update!(puntos_total: total, nivel: PerfilJuego.nivel_para(total))
      perfil
    end
  end
end
