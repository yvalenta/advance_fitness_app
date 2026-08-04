class RegistroCaloria < ApplicationRecord
  belongs_to :user

  validates :fecha, presence: true, uniqueness: { scope: :user_id }
  validates :kcal_consumidas, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # Macros del consumo (Fase 14.4): opcionales — nil significa "sin dato"
  validates :proteinas_g, :carbohidratos_g, :grasas_g,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Upsert del día (SDD §09): un registro por fecha; volver a enviar reemplaza.
  # `detalle` (opcional, Fase 5.8) guarda lo que el miembro dice que comió por
  # comida: { "comidas" => [{ "nombre", "kcal", "nota" }] }.
  # `proteinas_g`/`carbohidratos_g`/`grasas_g` (opcionales, Fase 14.4): gramos
  # del consumo real que suma el checklist del plan; igual que `detalle`, solo
  # se pisan cuando llegan — un registro manual de kcal no borra los macros
  # ya anotados del día.
  def self.registrar(user, kcal:, fecha: Date.current, detalle: nil,
                     proteinas_g: nil, carbohidratos_g: nil, grasas_g: nil)
    registro = user.registros_calorias.find_or_initialize_by(fecha:)
    atributos = { kcal_consumidas: kcal }
    atributos[:detalle] = detalle if detalle
    { proteinas_g:, carbohidratos_g:, grasas_g: }.each do |campo, gramos|
      atributos[campo] = gramos unless gramos.nil?
    end
    registro.update(atributos)
    registro
  end
end
