class Plan < ApplicationRecord
  CODIGOS = %w[free personalizado].freeze

  has_many :suscripciones, dependent: :restrict_with_error

  validates :codigo, inclusion: { in: CODIGOS }, uniqueness: true
  validates :nombre, presence: true
  validates :precio, numericality: { greater_than_or_equal_to: 0 }

  # Los dos planes del catálogo se autocrean si faltan (una base recién
  # desplegada sin seeds no debe romper el alta de suscripciones — Fase 5.11).
  # Los seeds siguen siendo la fuente rica (beneficios completos).
  def self.free
    find_or_create_by!(codigo: "free") do |plan|
      plan.nombre = "Plan Free"
      plan.precio = 0
      plan.beneficios = [ "Guías por objetivo", "Registro de calorías y progreso" ]
    end
  end

  def self.personalizado
    find_or_create_by!(codigo: "personalizado") do |plan|
      plan.nombre = "Plan Personalizado"
      plan.precio = Negocio.precio_personalizado
      plan.beneficios = [ "Rutina y nutrición generadas con IA", "Aprobado por tu entrenador",
                          "No pagas mensualidad de gimnasio" ]
    end
  end

  def personalizado? = codigo == "personalizado"
end
