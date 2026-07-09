class RegistroEntrenamiento < ApplicationRecord
  belongs_to :user

  validates :fecha, presence: true, uniqueness: { scope: :user_id }

  # Estado guardado de un ejercicio (por su índice dentro del día).
  def estado_de(indice) = ejercicios_hash[indice.to_s] || {}

  # Upsert del estado de un ejercicio del día (Fase 5.10): Hecho/Pendiente +
  # nota. Guarda también el nombre para que el historial sobreviva si el plan
  # cambia. No muta el plan del coach.
  def marcar!(indice, hecho:, nota:, nombre:)
    entrada = { "hecho" => hecho, "nota" => nota.to_s.strip, "nombre" => nombre.to_s }
    update!(ejercicios: ejercicios_hash.merge(indice.to_s => entrada))
  end

  private
    def ejercicios_hash = ejercicios || {}
end
