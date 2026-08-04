class RegistroEntrenamiento < ApplicationRecord
  belongs_to :user
  # Registro cuantitativo (series/reps/peso/RPE) — SDD §18. El JSONB
  # `ejercicios` sigue siendo solo el "marcar hecho" cualitativo de la UI.
  has_many :detalles, class_name: "DetalleEntrenamiento", dependent: :destroy
  has_one :feedback_ia, dependent: :destroy

  validates :fecha, presence: true, uniqueness: { scope: :user_id }

  # ── Formato del JSONB `ejercicios` (Fase 14.6) ────────────────────────────
  # v1 (histórico): clave = índice posicional → {"0" => {"hecho" => ...}, "novedad" => "..."}
  #   El índice se re-atribuía si el plan cambiaba de orden: ese es el bug.
  # v2: {"version" => 2, "novedad" => "...", "plan_id" => 42,
  #      "items" => {"<uid>" => {"hecho", "nota", "nombre", "dia", "indice"}}}
  #   `dia`/`indice` son metadato histórico para reconstruir la UI de registros
  #   viejos, NUNCA clave de búsqueda. Un registro es un hecho histórico: no se
  #   migran datos; la lectura entiende ambos formatos.
  VERSION_ACTUAL = 2

  # Estado guardado de un ejercicio. Busca `items[uid]` primero; cae al índice
  # posicional SOLO si el registro no tiene "version" (v1).
  def estado_de(uid: nil, indice: nil)
    clave = clave_item(uid, indice)
    item = clave && items_hash[clave]
    return item if item.is_a?(Hash)
    return {} if ejercicios_hash.key?("version") || indice.nil?

    estado = ejercicios_hash[indice.to_s]
    estado.is_a?(Hash) ? estado : {}
  end

  # Upsert del estado de un ejercicio del día (Fase 5.10): Hecho/Pendiente +
  # nota (nil = conservar la existente, incluida la de un registro v1). Guarda
  # nombre/dia/indice para que el historial sobreviva si el plan cambia — no
  # muta el plan del coach. Escribe SIEMPRE v2: si el registro era v1, sus
  # claves numéricas quedan intactas bajo "legacy" y estrena "items".
  def marcar!(uid:, hecho:, nombre:, dia:, indice:, nota: nil, plan_id: nil)
    entrada = { "hecho" => hecho,
                "nota" => (nota.nil? ? estado_de(uid: uid, indice: indice)["nota"].to_s : nota.to_s.strip),
                "nombre" => nombre.to_s, "dia" => dia.to_i, "indice" => indice.to_i }

    datos = promovido_a_v2
    datos["plan_id"] = plan_id if plan_id
    datos["items"] = items_hash.merge(clave_item(uid, indice) => entrada)
    update!(ejercicios: datos)
  end

  # ¿Ya hay algún ejercicio del día marcado como hecho? (Fase 14.12: el
  # primer "hecho" del día dispara los puntos del motor de juego). La clave
  # "novedad" guarda un String y se descarta sola con el is_a?(Hash).
  # Bi-formato (integración 14.6 + 14.12): en v2 los estados viven en "items";
  # en v1 son las claves numéricas del nivel superior. Recorrer solo el nivel
  # superior dejaría el v2 siempre en falso y el motor de juego encolaría un
  # job por CADA ejercicio marcado, no uno por día.
  def algun_ejercicio_hecho?
    estados = ejercicios_hash.key?("version") ? items_hash : ejercicios_hash
    estados.any? { |_clave, estado| estado.is_a?(Hash) && estado["hecho"] }
  end

  # Cuántos ejercicios del día están marcados "hecho" (dashboard Hoy, Fase
  # 14.5). Mismo recorrido bi-formato que algun_ejercicio_hecho?: en v2 los
  # estados viven en "items", en v1 son las claves numéricas del nivel
  # superior; "novedad" (String) y "legacy" se descartan con el is_a?(Hash).
  def conteo_hechos
    estados = ejercicios_hash.key?("version") ? items_hash : ejercicios_hash
    estados.count { |_clave, estado| estado.is_a?(Hash) && estado["hecho"] }
  end

  # Novedad del día para TODA la rutina (Fase 5.11): lesión, cambio de sede…
  # Vive en el nivel superior del JSONB, igual en v1 y v2.
  def novedad = ejercicios_hash["novedad"].to_s

  def marcar_novedad!(texto)
    update!(ejercicios: ejercicios_hash.merge("novedad" => texto.to_s.strip))
  end

  private
    def ejercicios_hash = ejercicios || {}

    def items_hash
      items = ejercicios_hash["items"]
      items.is_a?(Hash) ? items : {}
    end

    # Clave dentro de "items": el uid del ejercicio. Puente para planes previos
    # a la Fase 14.6 cuyas entradas aún no tienen uid: clave sintética "i<indice>"
    # — para esas entradas el anclaje sigue siendo posicional (el statu quo),
    # sin colisionar con los uids reales (alfanuméricos de 10).
    def clave_item(uid, indice)
      limpio = uid.to_s.strip
      return limpio if limpio.present?

      "i#{indice.to_i}" unless indice.nil?
    end

    # Copia v2 del JSONB actual lista para escribir. Un v1 se promueve: sus
    # claves numéricas se archivan bajo "legacy" (no se pierde nada) y la
    # novedad se conserva en el nivel superior.
    def promovido_a_v2
      datos = ejercicios_hash
      return datos.dup if datos.key?("version")

      legado = datos.select { |clave, _| clave.match?(/\A\d+\z/) }
      base = { "version" => VERSION_ACTUAL, "items" => {} }
      base["novedad"] = datos["novedad"] if datos.key?("novedad")
      base["legacy"] = legado if legado.any?
      base
    end
end
