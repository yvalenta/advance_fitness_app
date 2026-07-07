require "net/http"

# Adaptador Claude (Anthropic Messages API).
module Ia
  module ProveedorClaude
    # .presence: docker-compose exporta la variable como "" cuando no está en .env
    MODELO = (ENV["CLAUDE_MODELO"].presence || "claude-sonnet-5").freeze
    ENDPOINT = URI("https://api.anthropic.com/v1/messages").freeze
    VERSION_API = "2023-06-01".freeze
    MAX_TOKENS = 4096

    def self.completar(system:, prompt:)
      peticion = Net::HTTP::Post.new(ENDPOINT)
      peticion["x-api-key"] = api_key
      peticion["anthropic-version"] = VERSION_API
      peticion["content-type"] = "application/json"
      peticion.body = cuerpo(system:, prompt:).to_json

      respuesta = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, read_timeout: 120) do |http|
        http.request(peticion)
      end
      raise "Claude API #{respuesta.code}: #{respuesta.body.to_s.truncate(300)}" unless respuesta.is_a?(Net::HTTPSuccess)

      JSON.parse(respuesta.body).dig("content", 0, "text").to_s
    end

    def self.cuerpo(system:, prompt:)
      {
        model: MODELO,
        max_tokens: MAX_TOKENS,
        system: system,
        messages: [ { role: "user", content: prompt } ]
      }
    end

    def self.api_key
      ENV["ANTHROPIC_API_KEY"].presence ||
        Rails.application.credentials.anthropic_api_key ||
        raise("Falta ANTHROPIC_API_KEY (ENV o credentials)")
    end
    private_class_method :api_key
  end
end
