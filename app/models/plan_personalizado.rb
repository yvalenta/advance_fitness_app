class PlanPersonalizado < ApplicationRecord
  ESTADOS = %w[borrador aprobado].freeze
  GENERADORES = %w[ia entrenador].freeze

  belongs_to :user
  belongs_to :aprobado_por, class_name: "User", optional: true

  validates :estado, inclusion: { in: ESTADOS }
  validates :generado_por, inclusion: { in: GENERADORES }
  validates :rutina, :plan_nutricional, presence: true
  validates :aprobado_por, presence: true, if: :aprobado?

  scope :borradores, -> { where(estado: "borrador") }
  scope :aprobados, -> { where(estado: "aprobado") }

  def borrador? = estado == "borrador"
  def aprobado? = estado == "aprobado"

  # El entrenador puede ajustar el JSONB antes de publicar (SDD flujo B §10)
  def aprobar!(entrenador, rutina: nil, plan_nutricional: nil)
    update!(
      estado: "aprobado",
      aprobado_por: entrenador,
      rutina: rutina.presence || self.rutina,
      plan_nutricional: plan_nutricional.presence || self.plan_nutricional
    )
  end
end
