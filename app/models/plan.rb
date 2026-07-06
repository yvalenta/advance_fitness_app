class Plan < ApplicationRecord
  CODIGOS = %w[free personalizado].freeze

  has_many :suscripciones, dependent: :restrict_with_error

  validates :codigo, inclusion: { in: CODIGOS }, uniqueness: true
  validates :nombre, presence: true
  validates :precio, numericality: { greater_than_or_equal_to: 0 }

  def self.free = find_by(codigo: "free")
  def self.personalizado = find_by(codigo: "personalizado")

  def personalizado? = codigo == "personalizado"
end
