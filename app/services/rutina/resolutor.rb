# Resuelve la rutina efectiva de una semana del mesociclo (SDD Fase 14.7).
# Copy-on-write del contrato v2: una semana con "dias" => nil hereda la
# plantilla base aplicando su "ajuste"; una semana materializada (días
# propios) es la verdad tal cual — su ajuste quedó horneado al materializar,
# así que aquí no se reaplica. PORO puro: opera sobre el hash `rutina`, sin
# base ni sesión, y jamás muta sus entradas (siempre devuelve copias).
module Rutina
  module Resolutor
    # Solo un rango numérico claro ("8-12", con o sin espacios) se desplaza;
    # cualquier otro texto ("al fallo", "12", "3x10") queda intacto.
    RANGO_REPS = /\A(\d+)\s*-\s*(\d+)\z/
    AJUSTE_IDENTIDAD = { "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 }.freeze
    # Techo de seguridad al COMPONER ajustes (semana × módulo externo, p. ej.
    # ciclo menstrual): el factor combinado jamás sale de este rango.
    PESO_FACTOR_COMPUESTO = (0.7..1.25)

    # Días efectivos de la semana `numero`. `extra:` es un segundo ajuste
    # componible (se combina con el de la semana vía `componer`, con su clamp
    # de seguridad). Una semana desconocida o una rutina v1 devuelven la base
    # tal cual (identidad).
    def self.dias(rutina, numero, extra: nil)
      semana = Array(rutina["semanas"]).find { |sem| sem["numero"] == numero }

      if semana && !semana["dias"].nil?
        # Materializada: sus días ya traen el ajuste de la semana horneado;
        # solo un `extra` (siempre pasado por el clamp compuesto) se aplica.
        aplicar_ajuste(semana["dias"], extra ? componer(nil, extra) : nil)
      else
        ajuste = semana && semana["ajuste"]
        ajuste = componer(ajuste, extra) if extra
        aplicar_ajuste(Array(rutina["dias"]), ajuste)
      end
    end

    # Aplica un ajuste a una lista de días sin mutar la entrada:
    #   series        → [series + series_delta, 1].max
    #   peso_sugerido_kg → × peso_factor, redondeado a medios kilos
    #   repeticiones  → un rango "a-b" desplaza ambos extremos (piso 1)
    # uid/nombre/ejercicio_id/nota_tecnica/descanso_seg jamás se tocan: el
    # uid identifica al MISMO ejercicio a través de base y semanas. Cada
    # componente en identidad (delta 0 / factor 1.0) deja su campo EXACTO
    # (ni siquiera se normaliza el formato del rango de repeticiones).
    def self.aplicar_ajuste(dias, ajuste)
      ajuste = normalizar(ajuste)
      Array(dias).map do |dia|
        dia.deep_dup.tap do |nuevo|
          nuevo["ejercicios"] = Array(dia["ejercicios"]).map { |ej| ejercicio_ajustado(ej, ajuste) }
        end
      end
    end

    # Combina dos ajustes (cualquiera puede ser nil = identidad): los deltas
    # se suman y los factores de peso se multiplican, con clamp final del
    # factor a PESO_FACTOR_COMPUESTO.
    def self.componer(a, b)
      a = normalizar(a)
      b = normalizar(b)
      { "series_delta" => a["series_delta"] + b["series_delta"],
        "reps_delta" => a["reps_delta"] + b["reps_delta"],
        "peso_factor" => (a["peso_factor"] * b["peso_factor"]).clamp(PESO_FACTOR_COMPUESTO).round(3) }
    end

    def self.ejercicio_ajustado(ejercicio, ajuste)
      nuevo = ejercicio.deep_dup

      if ajuste["series_delta"] != 0 && ejercicio["series"]
        nuevo["series"] = [ ejercicio["series"].to_i + ajuste["series_delta"], 1 ].max
      end

      if ajuste["peso_factor"] != 1.0 && ejercicio["peso_sugerido_kg"]
        nuevo["peso_sugerido_kg"] = redondear_a_medios(ejercicio["peso_sugerido_kg"].to_f * ajuste["peso_factor"])
      end

      if ajuste["reps_delta"] != 0 && (rango = RANGO_REPS.match(ejercicio["repeticiones"].to_s))
        delta = ajuste["reps_delta"]
        nuevo["repeticiones"] = "#{[ rango[1].to_i + delta, 1 ].max}-#{[ rango[2].to_i + delta, 1 ].max}"
      end

      nuevo
    end
    private_class_method :ejercicio_ajustado

    # Redondeo a medios kilos (empates hacia arriba); enteros sin ".0" para
    # que el jsonb quede igual que lo que sanea el modelo (como_numero).
    def self.redondear_a_medios(kilos)
      valor = (kilos * 2).round / 2.0
      (valor % 1).zero? ? valor.to_i : valor
    end
    private_class_method :redondear_a_medios

    def self.normalizar(ajuste)
      crudo = (ajuste || {}).to_h.transform_keys(&:to_s)
      { "series_delta" => crudo["series_delta"].to_i,
        "reps_delta" => crudo["reps_delta"].to_i,
        "peso_factor" => (crudo["peso_factor"] || 1.0).to_f }
    end
    private_class_method :normalizar
  end
end
