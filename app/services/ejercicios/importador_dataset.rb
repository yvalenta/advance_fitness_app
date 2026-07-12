# Importa el catálogo de ejercicios (SDD Fase 6.1) desde el JSON del dataset
# hasaneyldrm/exercises-dataset (URL raw o ruta local). Upsert idempotente por
# dataset_id: puede correrse las veces que sea (incluso contra producción) sin
# duplicar, y NUNCA pisa un `nombre` ya editado/traducido — solo lo fija en
# registros nuevos o cuando sigue igual al original en inglés.
module Ejercicios
  module ImportadorDataset
    ORIGEN_DEFAULT = "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/data/exercises.json".freeze

    def self.importar(origen = ORIGEN_DEFAULT)
      filas = JSON.parse(leer(origen))
      resumen = { creados: 0, actualizados: 0, sin_cambio: 0 }

      filas.each do |fila|
        resumen[upsert(fila)] += 1
      end

      resumen
    end

    def self.upsert(fila)
      ejercicio = Ejercicio.find_or_initialize_by(dataset_id: fila.fetch("id"))
      nuevo = ejercicio.new_record?

      ejercicio.assign_attributes(atributos_desde(fila))
      # Conserva la traducción/edición local: solo renombra si nunca se tocó
      ejercicio.nombre = fila.fetch("name") if nuevo || ejercicio.nombre == ejercicio.nombre_en_was

      return :sin_cambio unless ejercicio.changed?

      ejercicio.save!
      nuevo ? :creados : :actualizados
    end

    def self.atributos_desde(fila)
      {
        nombre_en: fila.fetch("name"),
        musculo: Ejercicio.musculo_desde(fila["body_part"], fila["target"]),
        categoria: fila.fetch("body_part"),
        equipo: fila["equipment"],
        objetivo: fila["target"],
        musculos_secundarios: Array(fila["secondary_muscles"]),
        instrucciones: pasos_es(fila),
        imagen_ruta: fila["image"],
        gif_ruta: fila["gif_url"],
        atribucion: fila["attribution"].presence || "© Gym visual"
      }
    end

    # Prefiere los pasos ya separados; si solo hay texto corrido, lo parte por
    # oraciones para poder mostrarlo como lista numerada.
    def self.pasos_es(fila)
      pasos = fila.dig("instruction_steps", "es")
      return Array(pasos) if pasos.present?

      fila.dig("instructions", "es").to_s.split(/(?<=[.!?])\s+/).map(&:strip).reject(&:blank?)
    end

    def self.leer(origen)
      if origen.to_s.match?(%r{\Ahttps?://})
        require "open-uri"
        URI.parse(origen).open("rb", &:read)
      else
        File.read(origen)
      end
    end
  end
end
