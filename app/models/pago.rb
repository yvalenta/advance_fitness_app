class Pago < ApplicationRecord
  METODOS = %w[efectivo transferencia tarjeta].freeze

  belongs_to :membresia
  belongs_to :registrado_por, class_name: "User"

  validates :metodo, inclusion: { in: METODOS }
  validates :monto, numericality: { greater_than: 0 }
  validates :fecha_pago, :periodo_inicio, :periodo_fin, presence: true

  # El historial financiero es inmutable (SDD §08): se corrige con un
  # registro nuevo, nunca editando.
  def readonly? = persisted?
end
