# Biblioteca de ejercicios del entrenador para el editor de rutina (SDD Fase
# 5.7b). Agrupada por músculo; "otro" son ejercicios individuales sin
# categorizar. Nace con un seed y crece al guardar ejercicios como plantilla.
class PlantillaEjercicio < ApplicationRecord
  MUSCULOS = %w[pecho espalda pierna hombro biceps triceps core gluteo otro].freeze
  NOMBRES_MUSCULO = {
    "pecho" => "Pecho", "espalda" => "Espalda", "pierna" => "Pierna",
    "hombro" => "Hombro", "biceps" => "Bíceps", "triceps" => "Tríceps",
    "core" => "Core / Abdomen", "gluteo" => "Glúteo", "otro" => "Otros / Sin categoría"
  }.freeze

  belongs_to :creado_por, class_name: "User", optional: true

  validates :musculo, inclusion: { in: MUSCULOS }
  validates :nombre, presence: true, uniqueness: { scope: :musculo }
  validates :repeticiones, presence: true
  validates :series, :descanso_seg, numericality: { greater_than_or_equal_to: 0 }

  scope :ordenadas, -> { order(:musculo, :nombre) }
end
