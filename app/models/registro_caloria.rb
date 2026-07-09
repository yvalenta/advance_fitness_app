class RegistroCaloria < ApplicationRecord
  belongs_to :user

  validates :fecha, presence: true, uniqueness: { scope: :user_id }
  validates :kcal_consumidas, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Upsert del día (SDD §09): un registro por fecha; volver a enviar reemplaza.
  # `detalle` (opcional, Fase 5.8) guarda lo que el miembro dice que comió por
  # comida: { "comidas" => [{ "nombre", "kcal", "nota" }] }.
  def self.registrar(user, kcal:, fecha: Date.current, detalle: nil)
    registro = user.registros_calorias.find_or_initialize_by(fecha:)
    atributos = { kcal_consumidas: kcal }
    atributos[:detalle] = detalle if detalle
    registro.update(atributos)
    registro
  end
end
