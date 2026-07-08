# Biblioteca de comidas del entrenador para el editor de planes (SDD §07).
# Nace con un seed y crece cuando el entrenador guarda comidas ajustadas.
class PlantillaComida < ApplicationRecord
  TIPOS = %w[desayuno almuerzo cena snack].freeze
  NOMBRES_TIPO = {
    "desayuno" => "Desayunos", "almuerzo" => "Almuerzos",
    "cena" => "Cenas", "snack" => "Snacks y meriendas"
  }.freeze

  belongs_to :creado_por, class_name: "User", optional: true

  validates :tipo, inclusion: { in: TIPOS }
  validates :nombre, presence: true, uniqueness: { scope: :tipo }
  validates :descripcion, presence: true
  validates :kcal, numericality: { greater_than: 0 }
  validates :proteinas_g, :carbohidratos_g, :grasas_g,
            numericality: { greater_than_or_equal_to: 0 }

  scope :ordenadas, -> { order(:tipo, :nombre) }

  # Clasifica el nombre de una comida del plan ("Media Mañana", "Antes de
  # Dormir"…) en uno de los TIPOS, para agrupar el picker del editor.
  def self.tipo_para(nombre_comida)
    normalizado = nombre_comida.to_s.downcase
    return "desayuno" if normalizado.include?("desayuno")
    return "almuerzo" if normalizado.include?("almuerzo")
    return "cena" if normalizado.include?("cena") || normalizado.include?("dormir")

    "snack"
  end
end
