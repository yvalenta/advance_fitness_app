# PLACEHOLDER 14.9 — descartado en la integración a favor de la implementación real de 14.7.
#
# Fecha real de un día del mesociclo. Ancla la semana en curso del plan
# (`plan.semana_actual`) a la semana calendario actual (lunes) y desplaza desde
# ahí: para un plan v1 (1 semana identidad) reproduce exactamente el cálculo
# histórico `beginning_of_week + DIAS_OFFSET`, así el seguimiento del miembro
# sigue cayendo en las fechas de esta semana.
module Rutina
  class Calendario
    def self.fecha_de(plan, semana:, dia_indice:)
      dia = plan.dias(semana: semana)[dia_indice] || {}
      offset = PlanPersonalizado::DIAS_OFFSET.fetch(dia["dia"].to_s.downcase, dia_indice.to_i)
      inicio = Date.current.beginning_of_week - (plan.semana_actual - 1).weeks
      inicio + (semana.to_i - 1).weeks + offset
    end
  end
end
