# PLACEHOLDER 14.10 — descartado en la integración
#
# Contrato mínimo de Rutina::Calendario (lo implementa en paralelo la etapa
# del calendario de mesociclos) para desarrollar y probar la Etapa 14.10 de
# forma aislada. ResumenAdherencia e HistorialEntrenamiento lo resuelven en
# runtime (defined?/respond_to?), así que cuando lleguen el Calendario real
# y los helpers del plan (semana_actual/semanas) este archivo se borra sin
# tocar nada más.
module Rutina
  module CalendarioPlaceholder
    # Semana del mesociclo (base 1) a la que pertenece `fecha`, o nil si cae
    # fuera del ciclo del plan (antes de su inicio o después de su fin).
    def self.semana_de(plan, fecha)
      inicio = inicio_de(plan)
      return if fecha < inicio

      numero = ((fecha.to_date - inicio).to_i / 7) + 1
      numero if numero <= semanas(plan).size
    end

    # Mismo contrato que plan.semanas: array de { numero:, etiqueta:, descarga: }.
    # Un plan v1 (rutina sin "semanas") es el mesociclo identidad de 1 semana.
    def self.semanas(plan)
      lista = Array(plan.rutina["semanas"])
      return [ { numero: 1, etiqueta: "Semana 1", descarga: false } ] if lista.empty?

      lista.each_with_index.map do |semana, indice|
        { numero: semana["numero"] || indice + 1,
          etiqueta: semana["etiqueta"],
          descarga: semana["descarga"] == true }
      end
    end

    # Mismo contrato que plan.semana_actual.
    def self.semana_actual(plan)
      semana_de(plan, Date.current)
    end

    # Aproximación mínima: el ciclo arranca el lunes de la semana en que se
    # creó el plan.
    def self.inicio_de(plan)
      plan.created_at.to_date.beginning_of_week
    end
  end
end
