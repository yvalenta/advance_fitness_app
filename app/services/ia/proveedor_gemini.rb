require "net/http"

# Adaptador Gemini (Google Generative Language API). `responseMimeType`
# fuerza al modelo a responder JSON válido, sin fences. Si el modelo primario
# está ocupado (503/UNAVAILABLE), reintenta con un modelo de respaldo.
module Ia
  module ProveedorGemini
    # .presence: docker-compose exporta la variable como "" cuando no está en .env.
    # flash-lite: los modelos con thinking gastan el maxOutputTokens en razonar
    # y truncan el JSON; los "latest" sufren picos de demanda (503).
    MODELO = (ENV["GEMINI_MODELO"].presence || "gemini-2.5-flash-lite").freeze
    # Fallback cuando el primario está ocupado (503): misma generación 2.5 (con
    # cuota en la key), más robusto ante saturación. Solo se usa como respaldo,
    # así que su costo mayor casi no aplica. Parametrizable por ENV.
    MODELO_FALLBACK = (ENV["GEMINI_MODELO_FALLBACK"].presence || "gemini-2.5-flash").freeze
    MODELOS = [ MODELO, MODELO_FALLBACK ].uniq.freeze
    MAX_TOKENS = 16_384

    # Devuelve { texto:, modelo: } (el modelo que respondió).
    def self.completar(system:, prompt:)
      ultimo_error = nil
      MODELOS.each do |modelo|
        return { texto: pedir(modelo, system:, prompt:), modelo: modelo }
      rescue RuntimeError => error
        # Solo el "modelo ocupado" justifica probar el siguiente; lo demás se lanza.
        raise unless MensajeIa.ocupado?(error.message) && modelo != MODELOS.last
        ultimo_error = error
      end
      raise ultimo_error
    end

    def self.pedir(modelo, system:, prompt:)
      endpoint = URI("https://generativelanguage.googleapis.com/v1beta/models/#{modelo}:generateContent")
      peticion = Net::HTTP::Post.new(endpoint)
      peticion["x-goog-api-key"] = api_key
      peticion["content-type"] = "application/json"
      peticion.body = cuerpo(system:, prompt:).to_json

      respuesta = Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: true, read_timeout: 120) do |http|
        http.request(peticion)
      end
      raise "Gemini API #{respuesta.code}: #{respuesta.body.to_s.truncate(300)}" unless respuesta.is_a?(Net::HTTPSuccess)

      JSON.parse(respuesta.body).dig("candidates", 0, "content", "parts", 0, "text").to_s
    end
    private_class_method :pedir

    def self.cuerpo(system:, prompt:)
      {
        system_instruction: { parts: [ { text: system } ] },
        contents: [ { role: "user", parts: [ { text: prompt } ] } ],
        generationConfig: { responseMimeType: "application/json", maxOutputTokens: MAX_TOKENS }
      }
    end

    def self.api_key
      ENV["GEMINI_API_KEY"].presence ||
        Rails.application.credentials.gemini_api_key ||
        raise("Falta GEMINI_API_KEY (ENV o credentials)")
    end
    private_class_method :api_key
  end
end
