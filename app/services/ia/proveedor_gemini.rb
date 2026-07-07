require "net/http"

# Adaptador Gemini (Google Generative Language API). `responseMimeType`
# fuerza al modelo a responder JSON válido, sin fences.
module Ia
  module ProveedorGemini
    # .presence: docker-compose exporta la variable como "" cuando no está en .env.
    # flash-lite: los modelos con thinking gastan el maxOutputTokens en razonar
    # y truncan el JSON; los "latest" sufren picos de demanda (503).
    MODELO = (ENV["GEMINI_MODELO"].presence || "gemini-2.5-flash-lite").freeze
    ENDPOINT = URI("https://generativelanguage.googleapis.com/v1beta/models/#{MODELO}:generateContent").freeze
    MAX_TOKENS = 16_384

    def self.completar(system:, prompt:)
      peticion = Net::HTTP::Post.new(ENDPOINT)
      peticion["x-goog-api-key"] = api_key
      peticion["content-type"] = "application/json"
      peticion.body = cuerpo(system:, prompt:).to_json

      respuesta = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, read_timeout: 120) do |http|
        http.request(peticion)
      end
      raise "Gemini API #{respuesta.code}: #{respuesta.body.to_s.truncate(300)}" unless respuesta.is_a?(Net::HTTPSuccess)

      JSON.parse(respuesta.body).dig("candidates", 0, "content", "parts", 0, "text").to_s
    end

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
