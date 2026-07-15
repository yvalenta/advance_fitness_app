# Análisis con IA del historial cuantitativo del miembro (SDD §18). `estado`
# es el ciclo de vida del job (pendiente/generando/listo/fallido); `diagnostico`
# es la salida de negocio del prompt del Analista de Performance
# (progreso/estancado/alerta) — mismo patrón de PlanPersonalizado, adaptado.
class FeedbackIa < ApplicationRecord
  ESTADOS = %w[pendiente generando listo fallido].freeze
  DIAGNOSTICOS = %w[progreso estancado alerta].freeze
  # Fase 12: solo staff dispara el análisis hoy — "automatico" queda
  # reservado para un futuro disparador sin intervención humana.
  ORIGENES = %w[manual automatico].freeze

  belongs_to :registro_entrenamiento

  validates :estado, inclusion: { in: ESTADOS }
  validates :diagnostico, inclusion: { in: DIAGNOSTICOS }, allow_nil: true
  validates :origen, inclusion: { in: ORIGENES }

  # Un análisis real tarda segundos; más de esto casi siempre es un worker
  # que murió a mitad de camino (mismo umbral que PlanPersonalizado).
  MINUTOS_ANTES_DE_ESTANCARSE = 10
  scope :estancados, -> { where(estado: "generando").where(updated_at: ...MINUTOS_ANTES_DE_ESTANCARSE.minutes.ago) }

  def generando? = estado == "generando"
  def listo? = estado == "listo"
  def fallido? = estado == "fallido"

  def marcar_generando!(origen: self.origen)
    update!(estado: "generando", error: nil, origen: origen)
  end

  def completar!(diagnostico:, analisis:, accion_recomendada:, modelo:)
    update!(estado: "listo", diagnostico: diagnostico, analisis: analisis,
            accion_recomendada: accion_recomendada, modelo: modelo, error: nil)
  end

  def fallar!(mensaje)
    update!(estado: "fallido", error: mensaje.to_s.truncate(500), intentos: intentos + 1)
  end
end
