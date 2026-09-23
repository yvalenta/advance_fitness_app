module Progresion
  # Progresión lineal por reglas (Fase 20d, sin IA — coherente con
  # GeneradorPlanBasico): si el miembro completó TODAS las series
  # prescritas de un ejercicio, al peso que ya tenía sugerido, el peso
  # sugerido de ese ejercicio (por uid, en TODA la rutina — base y semanas
  # materializadas, Ejercicios::ValidadorRutina lo sabe recorrer) sube un
  # incremento fijo para la próxima vez. Nunca baja sola: un deload es
  # decisión del staff, no de la regla.
  #
  # "Prescritas" y "sugerido" son los EFECTIVOS de esa fecha (Nota 27g):
  # PlanPersonalizado#prescripcion_de, lo mismo que el modo sesión mostró y
  # registró — semana del mesociclo × fase del ciclo, reprogramación
  # resuelta. Comparar contra la base dejaba la regla viva solo en la
  # semana 1 del mesociclo. Un día liviano no es evidencia de progreso: ni
  # la semana de descarga, ni una fase del ciclo que recorte, ni una
  # prescripción por debajo de la base (ver mas_liviana?).
  #
  # El gate es "completó la sesión", no "tocó el tope del rango de reps":
  # el modo sesión registra SIEMPRE el piso del rango sin pedir que el
  # miembro escriba nada (Fase 18l, fricción cero) — comparar contra el
  # tope dejaría la regla inalcanzable en la práctica. Es progresión lineal
  # simple (tipo StrongLifts), no doble progresión dentro del rango.
  #
  # El guard de idempotencia (peso_sugerido_kg == peso_kg usado) evita
  # progresar dos veces si la última serie del día se reintenta por red: tras
  # el primer incremento el sugerido ya no coincide con lo que se levantó.
  #
  # Fuera de alcance V1 (Nota 27): ejercicios por tiempo, en superserie, o
  # sin peso externo (corporales) — progresan distinto o no progresan aún.
  module Regla
    INCREMENTO_KG = 2.5
    RANGO_REPS = /\A(\d+)\s*-\s*(\d+)\z/

    def self.evaluar_tras_serie!(user:, uid:, fecha:, ejercicio:)
      return if uid.blank?

      plan = user.plan_aprobado
      return unless plan

      prescripcion = plan.prescripcion_de(fecha)
      return if prescripcion.descarga? || Ciclo::Ajuste.baja_carga?(prescripcion.ajuste_ciclo)

      entrada = prescripcion.ejercicio(uid)
      return unless entrada
      return if entrada["tipo"] == "tiempo" || entrada["grupo_superserie"].present?
      return if mas_liviana?(entrada, buscar_entrada(plan.rutina, uid))

      series_prescritas = entrada["series"].to_i
      return unless series_prescritas.positive?

      detalles = DetalleEntrenamiento.joins(:registro_entrenamiento)
                                     .where(registro_entrenamiento: { user_id: user.id, fecha: fecha },
                                            ejercicio_id: ejercicio.id)
      return if detalles.count < series_prescritas
      return if detalles.any? { |detalle| detalle.peso_kg.blank? }

      piso = piso_reps(entrada["repeticiones"])
      return unless piso
      return unless detalles.all? { |detalle| detalle.repeticiones >= piso }

      peso_usado = detalles.first.peso_kg.to_f
      return if (entrada["peso_sugerido_kg"].to_f - peso_usado).abs > 0.01

      aplicar_incremento!(plan, uid)
    end

    def self.piso_reps(repeticiones)
      texto = repeticiones.to_s
      match = RANGO_REPS.match(texto)
      return match[1].to_i if match

      texto.to_i if texto.match?(/\A\d+\z/)
    end

    # Una prescripción efectiva por debajo de la base en peso, series o piso
    # de reps (una semana de 0.9 sin marca de descarga, un recorte manual del
    # staff en una semana materializada): completarla no prueba que el
    # miembro pueda con la base + el incremento.
    def self.mas_liviana?(efectiva, base)
      return false unless base

      efectiva["peso_sugerido_kg"].to_f < base["peso_sugerido_kg"].to_f ||
        efectiva["series"].to_i < base["series"].to_i ||
        piso_reps(efectiva["repeticiones"]).to_i < piso_reps(base["repeticiones"]).to_i
    end
    private_class_method :mas_liviana?

    # La entrada de referencia del uid: la de la plantilla base o, si el
    # staff la quitó de la base, la de la primera semana materializada.
    def self.buscar_entrada(rutina, uid)
      Ejercicios::ValidadorRutina.colecciones_de_dias(rutina).each do |dias|
        dias.each do |dia|
          entrada = Array(dia["ejercicios"]).find { |ej| ej["uid"] == uid }
          return entrada if entrada
        end
      end
      nil
    end
    private_class_method :buscar_entrada

    def self.aplicar_incremento!(plan, uid)
      rutina = plan.rutina
      tocado = false
      Ejercicios::ValidadorRutina.colecciones_de_dias(rutina).each do |dias|
        dias.each do |dia|
          Array(dia["ejercicios"]).each do |ej|
            next unless ej["uid"] == uid

            ej["peso_sugerido_kg"] = (ej["peso_sugerido_kg"].to_f + INCREMENTO_KG).round(1)
            tocado = true
          end
        end
      end
      plan.update!(rutina: rutina) if tocado
    end
    private_class_method :aplicar_incremento!
  end
end
