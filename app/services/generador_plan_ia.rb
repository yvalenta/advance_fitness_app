# Única integración con IA del MVP (SDD §04): una llamada estructurada que
# convierte el perfil + objetivo del miembro en un JSON de rutina semanal y
# plan nutricional. Sin LangChain: el prompt y el contrato JSON viven aquí,
# versionados en el repo; la llamada HTTP la resuelve un adaptador
# intercambiable (app/services/ia/) elegido por ENV["IA_PROVEEDOR"].
# Las API keys viven en credentials/ENV, jamás en vistas.
module GeneradorPlanIa
  PROVEEDORES = {
    "gemini" => Ia::ProveedorGemini,
    "claude" => Ia::ProveedorClaude
  }.freeze
  PROVEEDOR_DEFAULT = "gemini".freeze

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
    La rutina cubre de lunes a sábado (domingo descanso) y se enfoca en
    entrenamiento de FUERZA con pesos; NO incluyas días dedicados a cardio
    ni ejercicios de cardio como enfoque principal de un día. Las kcal de las
    comidas deben sumar aproximadamente el objetivo diario indicado.
  PROMPT

  # perfil: hash plano con los datos del miembro (sin objetos ActiveRecord).
  # Devuelve { rutina:, plan_nutricional:, modelo: } (modelo que respondió).
  def self.generar(perfil)
    respuesta = proveedor.completar(system: SYSTEM_PROMPT, prompt: construir_prompt(perfil))
    parsear(respuesta[:texto]).merge(modelo: respuesta[:modelo])
  end

  def self.proveedor
    nombre = ENV["IA_PROVEEDOR"].presence || PROVEEDOR_DEFAULT
    PROVEEDORES.fetch(nombre.downcase) do
      raise ArgumentError, "Proveedor de IA desconocido: #{nombre} (usa #{PROVEEDORES.keys.join(' | ')})"
    end
  end

  def self.construir_prompt(perfil)
    base = <<~PROMPT
      Genera la rutina semanal y el plan nutricional para este miembro:
      - Edad: #{perfil[:edad]} años · Sexo: #{perfil[:sexo] == "F" ? "mujer" : "hombre"}
      - Talla: #{perfil[:talla_cm]} cm · Peso: #{perfil[:peso_kg]} kg
      - Somatotipo: #{perfil[:somatotipo] || "sin clasificar"}
      - Nivel de actividad (factor TDEE): #{perfil[:nivel_actividad]}
      - Meta: #{perfil[:meta]} · Objetivo diario: #{perfil[:objetivo_kcal]} kcal (TDEE #{perfil[:tdee_kcal]} kcal)
    PROMPT
    base + antropometria(perfil[:medicion])
  end

  # Bloque opcional con las medidas antropométricas (Fase 5.9) para afinar la
  # rutina (puntos débiles por perímetros) y las porciones (% de grasa).
  def self.antropometria(medicion)
    return "" if medicion.nil?

    lineas = []
    lineas << "- Grasa corporal: #{medicion.grasa_pct}%" if medicion.grasa_pct
    { "Perímetros (cm)" => Medicion::PERIMETROS, "Diámetros óseos (cm)" => Medicion::DIAMETROS,
      "Pliegues (mm)" => Medicion::PLIEGUES }.each do |titulo, grupo|
      pares = medicion.presentes(grupo)
      lineas << "- #{titulo}: #{pares.map { |nombre, valor| "#{nombre} #{valor}" }.join(", ")}" if pares.any?
    end
    return "" if lineas.empty?

    "Medidas antropométricas recientes:\n#{lineas.join("\n")}\n"
  end

  # La respuesta puede venir envuelta en fences; se limpia y valida que
  # existan las dos claves del contrato antes de aceptarla.
  def self.parsear(texto)
    json = texto.strip.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, "")
    datos = JSON.parse(json)
    raise ArgumentError, "Respuesta de IA sin rutina o plan nutricional" unless
      datos.is_a?(Hash) && datos["rutina"].present? && datos["plan_nutricional"].present?

    { rutina: datos["rutina"], plan_nutricional: datos["plan_nutricional"] }
  end
end
