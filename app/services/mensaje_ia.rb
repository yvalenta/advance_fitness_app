# Traduce el error crudo de la IA a un mensaje corto y amable para el staff
# (SDD Fase 5.7). El texto crudo se conserva aparte en error_generacion.
module MensajeIa
  # [regex sobre el error crudo, mensaje amable]
  CASOS = [
    [ /credit|billing|quota exceeded|sin cr[eé]ditos/i, "La cuenta de IA se quedó sin créditos o cuota." ],
    [ /overloaded|unavailable|high demand|503|ocupad/i,  "El modelo de IA estaba ocupado; reintenta en un momento." ],
    [ /rate|429|too many/i,                              "Se alcanzó el límite de uso de la IA por ahora." ],
    [ /timeout|timed out|tard[oó]/i,                     "La IA tardó demasiado en responder." ],
    [ /json|parse|contrato|sin rutina/i,                 "La IA devolvió una respuesta inválida." ],
    [ /api key|falta .*key|401|403/i,                    "Falta configurar la clave de la IA." ]
  ].freeze

  GENERICO = "No se pudo generar el plan automáticamente.".freeze

  def self.amistoso(crudo)
    texto = crudo.to_s
    CASOS.find { |patron, _| texto.match?(patron) }&.last || GENERICO
  end

  # ¿El fallo fue por modelo ocupado? (para decidir el fallback de modelo)
  def self.ocupado?(crudo)
    crudo.to_s.match?(/overloaded|unavailable|high demand|503/i)
  end
end
