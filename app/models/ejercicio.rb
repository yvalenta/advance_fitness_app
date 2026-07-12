# Catálogo visual de ejercicios (SDD Fase 6). Cada fila viene del dataset
# hasaneyldrm/exercises-dataset: nombre en inglés (inmutable) + nombre en
# español (editable), instrucciones en español y media © Gym Visual servida
# por proxy con caché (Ejercicios::MediaCache). El músculo se mapea al enum
# de PlantillaEjercicio para integrarse con la biblioteca y el generador.
class Ejercicio < ApplicationRecord
  # body_part → músculo del dominio; "upper arms" y las piernas se afinan con
  # el target (biceps/triceps, glúteo) en .musculo_desde.
  MAPA_MUSCULO = {
    "chest" => "pecho", "back" => "espalda", "shoulders" => "hombro",
    "upper legs" => "pierna", "lower legs" => "pierna", "waist" => "core",
    "upper arms" => "otro", "lower arms" => "otro", "neck" => "otro", "cardio" => "otro"
  }.freeze

  has_many :plantillas_ejercicio, class_name: "PlantillaEjercicio", dependent: :nullify

  validates :dataset_id, presence: true, uniqueness: true
  validates :nombre, :nombre_en, :categoria, presence: true
  validates :musculo, inclusion: { in: PlantillaEjercicio::MUSCULOS }

  before_validation { self.nombre_normalizado = self.class.normalizar(nombre) }

  # Solo fuerza para el generador (cardio y cuello no arman rutina de pesas)
  scope :fuerza, -> { where.not(categoria: %w[cardio neck]) }
  scope :ordenados, -> { order(:musculo, :nombre) }

  def self.musculo_desde(body_part, target)
    objetivo = target.to_s.downcase
    return "biceps" if objetivo.include?("biceps")
    return "triceps" if objetivo.include?("triceps")
    return "gluteo" if objetivo.include?("glute")

    MAPA_MUSCULO.fetch(body_part.to_s.downcase, "otro")
  end

  # Fallback para rutinas viejas sin ejercicio_id: compara sin acentos ni
  # mayúsculas contra el nombre en español y el original en inglés.
  def self.buscar_por_nombre(texto)
    normalizado = normalizar(texto)
    return if normalizado.blank?

    find_by(nombre_normalizado: normalizado) ||
      where("LOWER(nombre_en) = ?", normalizado).first
  end

  def self.normalizar(texto)
    texto.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.strip
  end
end
