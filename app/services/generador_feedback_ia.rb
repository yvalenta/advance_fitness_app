# Analista de Performance (SDD §18.4, Fase 11-B): convierte las últimas
# series reales del miembro en un diagnóstico accionable. Mismo esqueleto
# que GeneradorPlanIa (proveedor intercambiable por ENV["IA_PROVEEDOR"],
# prompt versionado en el repo, respuesta JSON validada) aplicado a un
# contrato distinto — se duplica el selector de proveedor en vez de acoplar
# dos servicios de dominio distinto a un mixin compartido.
module GeneradorFeedbackIa
  PROVEEDORES = {
    "gemini" => Ia::ProveedorGemini,
    "claude" => Ia::ProveedorClaude
  }.freeze
  PROVEEDOR_DEFAULT = "gemini".freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    Actúa como un Entrenador Físico de Élite con especialización en Ciencias
    del Deporte y Análisis de Datos. Tu objetivo es interpretar la sesión de
    entrenamiento de HOY del usuario (todos sus ejercicios y series) para
    optimizar su progreso, usando el contexto de las últimas semanas como
    referencia de tendencia (no como el objeto del análisis).

    Recibirás la sesión completa a analizar (ejercicio, número de serie,
    repeticiones, peso en kg y RPE cuando esté disponible) y, por separado,
    un resumen semanal de volumen de las últimas semanas.

    Metodología:
    1. Progresión: evalúa si el volumen total de carga (series × reps × peso)
       por ejercicio en la sesión de hoy asciende, se estanca o desciende
       respecto al contexto histórico.
    2. Plateaus: detecta si lleva más de 3 sesiones sin subir peso ni
       repeticiones en un mismo ejercicio.
    3. Fatiga: un RPE alto y constante sin aumento de carga sugiere
       sobreentrenamiento.
    4. Ajuste prescriptivo: da un consejo técnico de máximo 3 líneas para la
       próxima sesión.

    Reglas: sé directo, técnico pero motivador; nunca sugieras aumentar la
    carga si la información sugiere técnica inconsistente; si hay una mejora
    notable, felicita mencionando el peso específico batido.

    Respondes ÚNICAMENTE con un objeto JSON válido, sin texto adicional ni
    fences de código, con esta estructura exacta:
    {
      "diagnostico": "progreso|estancado|alerta",
      "analisis": "breve interpretación de los datos",
      "accion_recomendada": "consejo técnico de máximo 3 líneas"
    }
  PROMPT

  # perfil: { series: [{ ejercicio:, fecha:, serie:, repeticiones:, peso_kg:, rpe: }, ...]
  #           (todas las de la sesión del día, sin objetos ActiveRecord),
  #           historial: [{ semana:, series:, volumen_kg: }, ...] (opcional) }.
  # Devuelve { diagnostico:, analisis:, accion_recomendada:, modelo: }.
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
    series = Array(perfil[:series])
    return "El miembro aún no tiene series registradas en la sesión de hoy." if series.empty?

    lineas = series.map do |s|
      "- #{s[:ejercicio]} serie #{s[:serie]}: #{s[:repeticiones]} reps" \
        "#{s[:peso_kg] ? " × #{s[:peso_kg]} kg" : " (peso corporal)"}#{s[:rpe] ? ", RPE #{s[:rpe]}" : ""}"
    end
    prompt = "Sesión de hoy a analizar (#{series.first[:fecha]}):\n#{lineas.join("\n")}"

    historial = Array(perfil[:historial])
    if historial.any?
      contexto = historial.map { |h| "- semana del #{h[:semana]}: #{h[:series]} series, #{h[:volumen_kg]} kg de volumen" }
      prompt += "\n\nContexto de las últimas semanas:\n#{contexto.join("\n")}"
    end

    prompt
  end

  # Tolera un diagnóstico fuera del contrato (cae a "alerta" con nota) para no
  # perder un análisis completo por una key inesperada del modelo; sí exige
  # que las 3 claves existan.
  def self.parsear(texto)
    json = texto.strip.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, "")
    datos = JSON.parse(json)
    raise ArgumentError, "Respuesta de IA incompleta" unless
      datos.is_a?(Hash) && datos["diagnostico"].present? && datos["analisis"].present? && datos["accion_recomendada"].present?

    diagnostico = datos["diagnostico"]
    unless FeedbackIa::DIAGNOSTICOS.include?(diagnostico)
      diagnostico = "alerta"
      datos["analisis"] = "#{datos["analisis"]} (diagnóstico original no reconocido: #{datos["diagnostico"].inspect})"
    end

    { diagnostico: diagnostico, analisis: datos["analisis"], accion_recomendada: datos["accion_recomendada"] }
  end
end
