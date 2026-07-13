# Traduce en lote los nombres del catálogo al español (Fase 6.7) usando el
# mismo proveedor IA del generador de planes. Idempotente y reanudable: solo
# toca ejercicios cuyo nombre sigue igual al original en inglés, así que las
# traducciones y ediciones manuales del staff nunca se pisan.
module Ejercicios
  module TraductorNombres
    LOTE = 100

    SYSTEM_PROMPT = <<~PROMPT.freeze
      Eres traductor especializado en fitness para un gimnasio en Colombia.
      Recibes una lista JSON de ejercicios [{"id": 1, "nombre_en": "..."}] y
      respondes ÚNICAMENTE un objeto JSON {"1": "nombre en español", ...} con
      la traducción natural de cada nombre tal como se usa en gimnasios de
      habla hispana (ej. "barbell bench press" → "Press de banca con barra").
      Conserva términos que se usan en inglés en el gimnasio (hip thrust,
      curl). Primera letra en mayúscula. Sin texto adicional.
    PROMPT

    # Devuelve el total de nombres traducidos en esta corrida.
    def self.traducir_pendientes(lote: LOTE, proveedor: GeneradorPlanIa.proveedor)
      total = 0

      loop do
        pendientes = Ejercicio.where("nombre = nombre_en").order(:id).limit(lote)
        break if pendientes.empty?

        traducciones = traducir_lote(pendientes, proveedor)
        aplicados = pendientes.count do |ejercicio|
          nombre = traducciones[ejercicio.id.to_s].presence
          next false if nombre.blank? || nombre == ejercicio.nombre_en

          ejercicio.update!(nombre: nombre.strip)
          true
        end
        break if aplicados.zero? # respuesta inservible: no ciclar infinito

        total += aplicados
        yield total if block_given?
      end

      total
    end

    def self.traducir_lote(ejercicios, proveedor)
      entrada = ejercicios.map { |e| { id: e.id, nombre_en: e.nombre_en } }.to_json
      respuesta = proveedor.completar(system: SYSTEM_PROMPT, prompt: entrada)
      json = respuesta[:texto].strip.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, "")
      datos = JSON.parse(json)
      datos.is_a?(Hash) ? datos : {}
    rescue JSON::ParserError
      {}
    end
  end
end
