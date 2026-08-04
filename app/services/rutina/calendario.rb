# Única verdad del calendario del mesociclo (SDD Fase 14.7): traduce entre
# (semana, día) del plan y fechas reales, en ambos sentidos. El inicio del
# mesociclo es rutina["mesociclo"]["inicio"] — lo fijan `publicar!` y
# `asegurar_sugerido!` al lunes de esa semana —; un plan v1 (sin mesociclo)
# arranca el lunes de la semana en que fue creado. PORO puro: lee el plan que
# recibe, sin tocar base ni sesión.
module Rutina
  module Calendario
    # Fecha real del día `dia_indice` (posición en rutina["dias"]) dentro de
    # la semana `semana` (1-based) del mesociclo. El offset desde el lunes
    # sale del nombre del día (PlanPersonalizado::DIAS_OFFSET); si el nombre
    # no es un día conocido se usa la propia posición como offset.
    def self.fecha_de(plan, semana:, dia_indice:)
      dia = plan.dias.fetch(dia_indice)
      offset = PlanPersonalizado::DIAS_OFFSET.fetch(dia["dia"].to_s) { dia_indice }
      inicio_de(plan) + ((semana - 1) * 7) + offset
    end

    # Semana del mesociclo (1-based) en la que cae `fecha`. Sin clamp a
    # propósito: puede dar <= 0 (fecha anterior al inicio) o > semanas_total
    # (mesociclo terminado); `PlanPersonalizado#semana_actual` aplica el clamp.
    def self.semana_de(plan, fecha)
      ((fecha.to_date - inicio_de(plan)).to_i / 7) + 1
    end

    # Lunes en que arranca el mesociclo (contrato v2) o, como fallback v1,
    # el lunes de la semana en que se creó el plan.
    def self.inicio_de(plan)
      inicio = plan.rutina.dig("mesociclo", "inicio") if plan.rutina.is_a?(Hash)
      inicio.present? ? Date.parse(inicio) : plan.created_at.to_date.beginning_of_week
    end
  end
end
