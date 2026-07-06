require "net/http"

# Única integración con IA del MVP (SDD §04): una llamada estructurada a la
# API de Claude que convierte el perfil + objetivo del miembro en un JSON de
# rutina semanal y plan nutricional. Sin LangChain: Net::HTTP y un prompt
# versionado en el repo. La API key vive en credentials/ENV, jamás en vistas.
module GeneradorPlanIa
  ENDPOINT = URI("https://api.anthropic.com/v1/messages").freeze
  MODELO = "claude-sonnet-5".freeze
  VERSION_API = "2023-06-01".freeze
  MAX_TOKENS = 4096

  SYSTEM_PROMPT = <<~PROMPT.freeze
    Eres un entrenador personal y nutricionista de un gimnasio en Colombia.
    Diseñas rutinas y planes de alimentación realistas para personas comunes,
    con alimentos disponibles en Colombia. Respondes ÚNICAMENTE con un objeto
    JSON válido, sin texto adicional ni fences de código, con esta estructura:
    {
      "rutina": {
        "dias": [
          { "dia": "lunes", "enfoque": "...", "ejercicios": [
            { "nombre": "...", "series": 4, "repeticiones": "8-10", "descanso_seg": 90 }
          ] }
        ]
      },
      "plan_nutricional": {
        "kcal_diarias": 0,
        "comidas": [
          { "nombre": "Desayuno", "descripcion": "...", "kcal": 0,
            "proteinas_g": 0, "carbohidratos_g": 0, "grasas_g": 0 }
        ]
      }
    }
    La rutina cubre de lunes a sábado (domingo descanso). Las kcal de las
    comidas deben sumar aproximadamente el objetivo diario indicado.
  PROMPT

  # perfil: hash plano con los datos del miembro (sin objetos ActiveRecord)
  def self.generar(perfil)
    respuesta = llamar_api(construir_prompt(perfil))
    parsear(respuesta)
  end

  def self.construir_prompt(perfil)
    <<~PROMPT
      Genera la rutina semanal y el plan nutricional para este miembro:
      - Edad: #{perfil[:edad]} años · Sexo: #{perfil[:sexo] == "F" ? "mujer" : "hombre"}
      - Talla: #{perfil[:talla_cm]} cm · Peso: #{perfil[:peso_kg]} kg
      - Somatotipo: #{perfil[:somatotipo] || "sin clasificar"}
      - Nivel de actividad (factor TDEE): #{perfil[:nivel_actividad]}
      - Meta: #{perfil[:meta]} · Objetivo diario: #{perfil[:objetivo_kcal]} kcal (TDEE #{perfil[:tdee_kcal]} kcal)
    PROMPT
  end

  # La respuesta de Claude puede venir envuelta en fences; se limpia y valida
  # que existan las dos claves del contrato antes de aceptarla.
  def self.parsear(texto)
    json = texto.strip.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, "")
    datos = JSON.parse(json)
    raise ArgumentError, "Respuesta de IA sin rutina o plan nutricional" unless
      datos.is_a?(Hash) && datos["rutina"].present? && datos["plan_nutricional"].present?

    { rutina: datos["rutina"], plan_nutricional: datos["plan_nutricional"] }
  end

  def self.llamar_api(prompt)
    peticion = Net::HTTP::Post.new(ENDPOINT)
    peticion["x-api-key"] = api_key
    peticion["anthropic-version"] = VERSION_API
    peticion["content-type"] = "application/json"
    peticion.body = {
      model: MODELO,
      max_tokens: MAX_TOKENS,
      system: SYSTEM_PROMPT,
      messages: [ { role: "user", content: prompt } ]
    }.to_json

    respuesta = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, read_timeout: 120) do |http|
      http.request(peticion)
    end
    raise "Claude API #{respuesta.code}: #{respuesta.body.to_s.truncate(300)}" unless respuesta.is_a?(Net::HTTPSuccess)

    JSON.parse(respuesta.body).dig("content", 0, "text").to_s
  end
  private_class_method :llamar_api

  def self.api_key
    ENV["ANTHROPIC_API_KEY"].presence ||
      Rails.application.credentials.anthropic_api_key ||
      raise("Falta ANTHROPIC_API_KEY (ENV o credentials)")
  end
  private_class_method :api_key
end
