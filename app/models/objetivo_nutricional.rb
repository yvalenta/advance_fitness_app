class ObjetivoNutricional < ApplicationRecord
  TIPOS = %w[deficit superavit mantenimiento].freeze
  NOMBRES = { "deficit" => "Bajar de peso", "superavit" => "Ganar masa", "mantenimiento" => "Mantenerme" }.freeze

  belongs_to :user

  validates :tipo, inclusion: { in: TIPOS }
  validates :peso_kg, numericality: { greater_than: 0, less_than: 400 }
  validates :tdee_kcal, :objetivo_kcal, presence: true
  validate :usuario_con_perfil_completo, on: :create

  before_validation :calcular_snapshot, on: :create

  # Fija el objetivo del miembro: desactiva el anterior y guarda el nuevo con
  # su snapshot (peso, TDEE y kcal objetivo) en una transacción.
  def self.fijar_para(user, tipo:, peso_kg:)
    objetivo = user.objetivos_nutricionales.new(tipo:, peso_kg:, activo: true)
    return objetivo unless objetivo.valid?

    transaction do
      user.objetivos_nutricionales.where(activo: true).update_all(activo: false, updated_at: Time.current)
      objetivo.save!
    end
    objetivo
  end

  def nombre = NOMBRES.fetch(tipo, tipo)

  def kcal_restantes(consumidas)
    objetivo_kcal - consumidas.to_i
  end

  private

  # El TDEE y el objetivo no se reciben del formulario: se calculan con los
  # services puros a partir del perfil + peso (SDD §04: solo se guardan inputs
  # y su snapshot).
  def calcular_snapshot
    return unless user&.perfil_nutricional_completo? && peso_kg.to_f.positive?

    self.tdee_kcal = CalculadoraTdee.tdee(
      peso_kg: peso_kg.to_f, talla_cm: user.talla_cm.to_f, edad: user.edad,
      sexo: user.sexo, nivel_actividad: user.nivel_actividad.to_f
    )
    self.objetivo_kcal = ObjetivoCalorico.kcal(tdee: tdee_kcal, tipo:, somatotipo: user.somatotipo)
  end

  def usuario_con_perfil_completo
    return if user&.perfil_nutricional_completo?

    errors.add(:base, "Completa tu perfil (fecha de nacimiento, sexo, talla y nivel de actividad) antes de fijar un objetivo")
  end
end
