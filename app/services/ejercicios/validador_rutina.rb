# Valida la rutina que devuelve la IA contra el catálogo real (Fase 6.5):
# la IA debe usar ejercicio_id del CATÁLOGO PERMITIDO, pero puede alucinar.
# Reglas: id válido → se pisa el nombre con el del catálogo (consistencia);
# id inválido → rescate por nombre; sin match → se elimina el id pero el
# ejercicio sobrevive. NUNCA tumba el plan; devuelve el conteo de arreglos.
# Mesociclo v2 (Fase 14.8): también sanea la alucinación NUMÉRICA de los
# ajustes semanales y recorre los días materializados de cada semana.
module Ejercicios
  module ValidadorRutina
    # Límites duros del ajuste semanal e identidad para valores no numéricos:
    # un peso_factor de 9.0 o un series_delta de 50 son alucinaciones, no
    # progresión.
    LIMITES_AJUSTE = { "series_delta" => [ -2, 2 ], "peso_factor" => [ 0.5, 1.5 ],
                       "reps_delta" => [ -2, 2 ] }.freeze
    IDENTIDAD_AJUSTE = { "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 }.freeze
    RANGO_SEMANAS_TOTAL = (1..8).freeze

    # Progresión lineal por defecto del mesociclo v2 (Fase 14.8): fuente única
    # que comparten GeneradorPlanIa.parsear (cuando la IA responde solo la
    # base v1) y GeneradorPlanBasico. La última semana SIEMPRE es descarga.
    SEMANAS_DEFAULT = [ [ "Adaptación", 1.0, false ], [ "Acumulación", 1.05, false ],
                        [ "Intensificación", 1.1, false ], [ "Descarga", 0.85, true ] ].freeze

    # Hashes nuevos en cada llamada: cada plan es dueño de su progresión.
    def self.progresion_defecto
      semanas = SEMANAS_DEFAULT.each_with_index.map do |(etiqueta, factor, descarga), indice|
        { "numero" => indice + 1, "etiqueta" => etiqueta, "descarga" => descarga,
          "ajuste" => { "series_delta" => 0, "peso_factor" => factor, "reps_delta" => 0 },
          "dias" => nil }
      end
      { "mesociclo" => { "nombre" => "Mesociclo lineal de 4 semanas", "semanas_total" => semanas.size,
                         "inicio" => nil, "progresion" => "lineal" },
        "semanas" => semanas }
    end

    def self.corregir!(rutina)
      correcciones = 0
      correcciones += sanear_mesociclo!(rutina) if rutina.is_a?(Hash) && v2?(rutina)

      colecciones_de_dias(rutina).each do |dias|
        dias.each do |dia|
          next unless dia.is_a?(Hash)

          Array(dia["ejercicios"]).each do |ejercicio|
            # uid (Fase 14.6): la IA no lo conoce (no va en su prompt), así que
            # aquí se estrena la identidad estable de cada entrada. No cuenta
            # como corrección: no es un arreglo del catálogo.
            ejercicio["uid"] = SecureRandom.alphanumeric(10) if ejercicio["uid"].to_s.strip.empty?
            correcciones += 1 unless corregir_ejercicio(ejercicio)
          end
        end
      end

      { rutina: rutina, correcciones: correcciones }
    end

    # true si el ejercicio quedó bien referenciado sin necesidad de arreglo
    def self.corregir_ejercicio(ejercicio)
      encontrado = Ejercicio.find_by(id: ejercicio["ejercicio_id"])

      if encontrado
        return true if ejercicio["nombre"] == encontrado.nombre

        ejercicio["nombre"] = encontrado.nombre
      elsif (rescatado = Ejercicio.buscar_por_nombre(ejercicio["nombre"]))
        ejercicio["ejercicio_id"] = rescatado.id
      else
        ejercicio.delete("ejercicio_id")
      end
      false
    end

    # Solo entra al saneo del mesociclo la rutina que dice ser v2; una rutina
    # v1 (planes viejos ya guardados) pasa exactamente igual que siempre.
    def self.v2?(rutina)
      rutina.key?("semanas") || rutina.key?("mesociclo") || rutina["version"].to_i >= 2
    end

    # La semana base + los días materializados de cada semana (si existen):
    # el anti-alucinación de catálogo y el uid aplican a TODAS las copias.
    def self.colecciones_de_dias(rutina)
      return [] unless rutina.is_a?(Hash)

      [ rutina["dias"], *Array(rutina["semanas"]).filter_map { |semana| semana.is_a?(Hash) ? semana["dias"] : nil } ]
        .map { |dias| Array(dias) }
    end

    # Anti-alucinación numérica del mesociclo (Fase 14.8): clamps sobre los
    # ajustes, semanas_total dentro de 1..8 y reconstrucción de la progresión
    # por defecto si "semanas" viene irreconocible. Jamás tumba el plan;
    # devuelve cuántos saneos aplicó (van al contador de correcciones).
    def self.sanear_mesociclo!(rutina)
      sanear_semanas!(rutina) + sanear_datos_mesociclo!(rutina)
    end

    def self.sanear_semanas!(rutina)
      semanas = rutina["semanas"]
      unless semanas.is_a?(Array) && semanas.any? && semanas.all?(Hash)
        rutina["semanas"] = progresion_defecto["semanas"]
        # nil = síntesis silenciosa (faltaba); otra cosa = basura que se corrige
        return semanas.nil? ? 0 : 1
      end

      semanas.sum { |semana| sanear_ajuste!(semana) }
    end

    def self.sanear_ajuste!(semana)
      crudo = semana["ajuste"]
      base = crudo.is_a?(Hash) ? crudo : {}
      arreglos = crudo.nil? || crudo.is_a?(Hash) ? 0 : 1

      semana["ajuste"] = LIMITES_AJUSTE.each_with_object({}) do |(clave, (minimo, maximo)), ajuste|
        numero = a_numero(base[clave])
        if numero.nil?
          # No numérico → identidad; solo cuenta si venía basura (nil es omisión)
          arreglos += 1 unless base[clave].nil?
          ajuste[clave] = IDENTIDAD_AJUSTE[clave]
        else
          saneado = numero.clamp(minimo, maximo)
          arreglos += 1 if saneado != numero
          ajuste[clave] = clave == "peso_factor" ? saneado.round(2) : saneado.round
        end
      end
      arreglos
    end

    def self.sanear_datos_mesociclo!(rutina)
      mesociclo = rutina["mesociclo"]
      unless mesociclo.is_a?(Hash)
        rutina["mesociclo"] = progresion_defecto["mesociclo"].merge("semanas_total" => rutina["semanas"].size)
        return mesociclo.nil? ? 0 : 1
      end

      total = a_numero(mesociclo["semanas_total"])
      if total.nil?
        arreglos = mesociclo["semanas_total"].nil? ? 0 : 1
        mesociclo["semanas_total"] = rutina["semanas"].size
        arreglos
      else
        saneado = total.round.clamp(RANGO_SEMANAS_TOTAL)
        mesociclo["semanas_total"] = saneado
        saneado == total ? 0 : 1
      end
    end

    def self.a_numero(valor)
      Float(valor)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
