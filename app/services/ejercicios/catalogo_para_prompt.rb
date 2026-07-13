# Condensa el catálogo para el prompt de IA (Fase 6.5): 1.324 ejercicios no
# caben, así que se envía un subconjunto por músculo con formato
# "id | nombre (equipo)". Prioriza los ejercicios curados (enlazados a
# plantillas de la biblioteca) y completa con el resto del catálogo de fuerza.
module Ejercicios
  module CatalogoParaPrompt
    LIMITE_POR_MUSCULO = 12
    MUSCULOS = (PlantillaEjercicio::MUSCULOS - %w[otro]).freeze

    def self.para(limite_por_musculo: LIMITE_POR_MUSCULO)
      curados = Ejercicio.fuerza.joins(:plantillas_ejercicio).distinct.group_by(&:musculo)
      resto = Ejercicio.fuerza.ordenados.group_by(&:musculo)

      bloques = MUSCULOS.filter_map do |musculo|
        seleccion = (Array(curados[musculo]) + Array(resto[musculo])).uniq.first(limite_por_musculo)
        next if seleccion.empty?

        lineas = seleccion.map { |e| "#{e.id} | #{e.nombre}#{" (#{e.equipo})" if e.equipo.present?}" }
        "#{PlantillaEjercicio::NOMBRES_MUSCULO.fetch(musculo, musculo).upcase}:\n#{lineas.join("\n")}"
      end

      bloques.join("\n\n")
    end
  end
end
