class RegistroEntrenamiento < ApplicationRecord
  belongs_to :user
  # Registro cuantitativo (series/reps/peso/RPE) — SDD §18. El JSONB
  # `ejercicios` sigue siendo solo el "marcar hecho" cualitativo de la UI.
  has_many :detalles, class_name: "DetalleEntrenamiento", dependent: :destroy

  validates :fecha, presence: true, uniqueness: { scope: :user_id }

  # Estado guardado de un ejercicio (por su índice dentro del día).
  def estado_de(indice) = ejercicios_hash[indice.to_s] || {}

  # Upsert del estado de un ejercicio del día (Fase 5.10): Hecho/Pendiente +
  # nota (nil = conservar la existente). Guarda también el nombre para que el
  # historial sobreviva si el plan cambia. No muta el plan del coach.
  def marcar!(indice, hecho:, nombre:, nota: nil)
    entrada = { "hecho" => hecho,
                "nota" => (nota.nil? ? estado_de(indice)["nota"].to_s : nota.to_s.strip),
                "nombre" => nombre.to_s }
    update!(ejercicios: ejercicios_hash.merge(indice.to_s => entrada))
  end

  # Novedad del día para TODA la rutina (Fase 5.11): lesión, cambio de sede…
  def novedad = ejercicios_hash["novedad"].to_s

  def marcar_novedad!(texto)
    update!(ejercicios: ejercicios_hash.merge("novedad" => texto.to_s.strip))
  end

  private
    def ejercicios_hash = ejercicios || {}
end
