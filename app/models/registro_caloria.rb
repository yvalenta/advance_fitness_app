class RegistroCaloria < ApplicationRecord
  belongs_to :user

  validates :fecha, presence: true, uniqueness: { scope: :user_id }
  validates :kcal_consumidas, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Upsert del día (SDD §09): un registro por fecha; volver a enviar reemplaza.
  def self.registrar(user, kcal:, fecha: Date.current)
    registro = user.registros_calorias.find_or_initialize_by(fecha:)
    registro.update(kcal_consumidas: kcal)
    registro
  end
end
