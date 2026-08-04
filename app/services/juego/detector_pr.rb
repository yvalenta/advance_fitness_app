module Juego
  # Detección de récords personales (Fase 14.13). Se llama INLINE desde el
  # create de series — no vía OtorgarPuntosJob — porque el resultado decide
  # la respuesta HTTP (la celebración turbo_stream) y cuesta una query por
  # tipo. Los puntos sí pasan por Juego::Otorgador, como todo el ledger.
  #
  # Las series creadas por `DetalleEntrenamiento.registrar_cumplido!` (peso
  # sugerido del plan, §18.7) también compiten: el miembro confirmó haberlas
  # ejecutado, así que es peso REAL levantado — que el número venga
  # precargado del plan no lo hace menos cierto que uno digitado a mano.
  class DetectorPr
    # Evalúa una serie recién guardada contra los PRs vigentes de su
    # (user, ejercicio) y devuelve los récords NUEVOS (0, 1 o 2: una serie
    # pesada puede batir peso_max y volumen_max a la vez).
    #
    # El primer registro de una marca NO es PR: crea la fila baseline
    # (baseline: true, sin puntos ni celebración) — es la vara a batir desde
    # la siguiente sesión; sin ella, el día 1 sería una lluvia de "récords"
    # sin mérito.
    #
    # Idempotente: re-evaluar el mismo detalle compara su valor contra el PR
    # que él mismo dejó vigente → empate → no-op; y si un reintento llegara
    # a repetir el otorgamiento, la constraint única del ledger
    # (user, tipo, origen) lo vuelve no-op también.
    def self.evaluar!(detalle)
      user = detalle.registro_entrenamiento.user
      marcas(detalle).filter_map { |tipo, valor| superar!(user, detalle, tipo, valor) }
    end

    # Marcas en las que compite la serie: con peso externo compite en peso y
    # volumen; a peso corporal (peso_kg nil o 0), solo en repeticiones — no
    # se comparan dominadas lastradas contra libres, ni el volumen 0 de una
    # serie corporal contra cargas reales.
    def self.marcas(detalle)
      if detalle.peso_kg.present? && detalle.peso_kg.positive?
        { "peso_max" => detalle.peso_kg, "volumen_max" => detalle.volumen_kg }
      else
        { "reps_max" => detalle.repeticiones }
      end
    end

    def self.superar!(user, detalle, tipo, valor)
      vigente = RecordPersonal.vigentes.find_by(user: user, ejercicio: detalle.ejercicio, tipo: tipo)
      if vigente.nil?
        crear!(user, detalle, tipo, valor, baseline: true)
        return # baseline: sin puntos ni celebración
      end
      return if valor <= vigente.valor # empatar la marca NO la supera

      # El PR superado no se borra (historial, como pagos.anulado_en): se le
      # marca superado_en y el índice único parcial deja entrar al nuevo.
      RecordPersonal.transaction do
        vigente.update!(superado_en: Time.current)
        nuevo = crear!(user, detalle, tipo, valor, baseline: false)
        Juego::Otorgador.otorgar!(user, tipo: "pr", origen: nuevo, fecha: nuevo.fecha)
        nuevo
      end
    end

    def self.crear!(user, detalle, tipo, valor, baseline:)
      RecordPersonal.create!(user: user, ejercicio: detalle.ejercicio, tipo: tipo, valor: valor,
                             repeticiones: detalle.repeticiones, peso_kg: detalle.peso_kg,
                             fecha: detalle.registro_entrenamiento.fecha,
                             detalle_entrenamiento: detalle, baseline: baseline)
    end
  end
end
