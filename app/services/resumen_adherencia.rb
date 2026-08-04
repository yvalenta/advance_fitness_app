# Resume el seguimiento real del miembro (Fase 6.6) para retroalimentar la
# generación del plan: % global de checks, adherencia por ejercicio y las
# últimas novedades reportadas (lesiones, máquinas ocupadas…). Devuelve nil
# si no hay registros en el rango — el prompt simplemente omite el bloque.
# Con `plan:` (el plan vigente, Etapa 14.10) agrega además la adherencia por
# semana del mesociclo (por_semana / fuera_de_ciclo) y el texto de posición
# en el ciclo (contexto_ciclo) que consume el prompt de regeneración.
module ResumenAdherencia
  NOVEDADES_MAX = 5

  def self.para(user, semanas: 4, plan: nil)
    desde = Date.current.beginning_of_week - (semanas - 1).weeks
    registros = user.registros_entrenamiento.where(fecha: desde..Date.current)
    return if registros.none?

    conteos = Hash.new { |h, k| h[k] = { hechos: 0, total: 0 } }
    novedades = []

    registros.order(:fecha).each do |registro|
      registro.ejercicios.each do |clave, estado|
        if clave == "novedad"
          novedades << estado if estado.present?
        elsif clave.match?(/\A\d+\z/) && estado.is_a?(Hash)
          nombre = estado["nombre"].presence || "Ejercicio #{clave.to_i + 1}"
          conteos[nombre][:total] += 1
          conteos[nombre][:hechos] += 1 if estado["hecho"]
        end
      end
    end
    return if conteos.empty? && novedades.empty?

    total = conteos.values.sum { |c| c[:total] }
    hechos = conteos.values.sum { |c| c[:hechos] }
    resumen = {
      semanas: semanas,
      pct_global: total.zero? ? 0 : (hechos * 100.0 / total).round,
      por_ejercicio: conteos.map { |nombre, c| { nombre: nombre, hechos: c[:hechos], total: c[:total] } },
      novedades: novedades.last(NOVEDADES_MAX)
    }
    plan ? resumen.merge(seguimiento_del_ciclo(registros, plan)) : resumen
  end

  # ── Etapa 14.10: adherencia por semana del mesociclo ─────────────────────
  # Cada registro se ubica en su semana vía Rutina::Calendario.semana_de; lo
  # que cae antes del inicio (o después del fin) del ciclo va al bucket
  # fuera_de_ciclo para no contaminar las semanas. El conteo aquí es
  # bi-formato (14.6): suma toda entrada hash con "hecho", tenga clave de
  # índice numérico (v1) o el esquema de claves v2.
  def self.seguimiento_del_ciclo(registros, plan)
    metadatos = semanas_del(plan)
    buckets = Hash.new { |h, k| h[k] = { hechos: 0, total: 0 } }
    fuera = { hechos: 0, total: 0 }

    registros.each do |registro|
      hechos, total = conteo_bi_formato(registro)
      next if total.zero?

      numero = calendario.semana_de(plan, registro.fecha)
      destino = numero ? buckets[numero] : fuera
      destino[:hechos] += hechos
      destino[:total] += total
    end

    { por_semana: buckets.keys.sort.map { |numero| semana_resumida(metadatos, numero, buckets[numero]) },
      fuera_de_ciclo: fuera[:total].zero? ? nil : fuera.merge(porcentaje: porcentaje_de(fuera)),
      contexto_ciclo: contexto_ciclo(plan, metadatos) }
  end

  # "Va en la semana 3 de 4 (Intensificación); la próxima es descarga." Un
  # plan v1 (una sola semana identidad) no tiene ciclo que narrar → nil.
  def self.contexto_ciclo(plan, metadatos = semanas_del(plan))
    return if metadatos.size <= 1

    actual = semana_actual_del(plan)
    return "El mesociclo de #{metadatos.size} semanas ya terminó; el nuevo plan arranca un ciclo nuevo." if actual.nil?

    etiqueta = dato(meta_de(metadatos, actual) || {}, :etiqueta)
    posicion = "Va en la semana #{actual} de #{metadatos.size}"
    posicion += " (#{etiqueta})" if etiqueta.present?
    "#{posicion}#{proxima_semana(metadatos, actual)}"
  end

  def self.proxima_semana(metadatos, actual)
    siguiente = meta_de(metadatos, actual + 1)
    return "; es la última semana del ciclo." if siguiente.nil?
    return "; la próxima es descarga." if dato(siguiente, :descarga) == true

    etiqueta = dato(siguiente, :etiqueta)
    etiqueta.present? ? "; la próxima es #{etiqueta}." : "; la próxima es la semana #{actual + 1}."
  end

  def self.semana_resumida(metadatos, numero, conteo)
    meta = meta_de(metadatos, numero) || {}
    { numero: numero, etiqueta: dato(meta, :etiqueta), descarga: dato(meta, :descarga) == true,
      hechos: conteo[:hechos], total: conteo[:total], porcentaje: porcentaje_de(conteo) }
  end

  # [hechos, total] de un registro contando cualquier entrada con "hecho" —
  # tolerante al formato del jsonb ("novedad" y demás strings no cuentan).
  def self.conteo_bi_formato(registro)
    estados = registro.ejercicios.values.select { |estado| estado.is_a?(Hash) && estado.key?("hecho") }
    [ estados.count { |estado| estado["hecho"] }, estados.size ]
  end

  def self.porcentaje_de(conteo)
    (conteo[:hechos] * 100.0 / conteo[:total]).round
  end

  def self.meta_de(metadatos, numero)
    metadatos.find { |semana| dato(semana, :numero) == numero }
  end

  # Los metadatos de semana pueden llegar con claves símbolo o string según
  # quién los construya (modelo vs jsonb) — se aceptan ambas.
  def self.dato(hash, clave)
    hash[clave].nil? ? hash[clave.to_s] : hash[clave]
  end

  # ── Resolución contract-first (14.10) ────────────────────────────────────
  # Rutina::Calendario y los helpers del plan (semanas / semana_actual) los
  # integra la etapa del calendario de mesociclos; mientras no existan en
  # este árbol responde el placeholder (descartado en la integración).
  def self.calendario
    defined?(Rutina::Calendario) ? Rutina::Calendario : Rutina::CalendarioPlaceholder
  end

  def self.semanas_del(plan)
    plan.respond_to?(:semanas) ? plan.semanas : Rutina::CalendarioPlaceholder.semanas(plan)
  end

  def self.semana_actual_del(plan)
    plan.respond_to?(:semana_actual) ? plan.semana_actual : Rutina::CalendarioPlaceholder.semana_actual(plan)
  end
end
