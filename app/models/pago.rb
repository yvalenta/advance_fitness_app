class Pago < ApplicationRecord
  METODOS = %w[efectivo transferencia tarjeta].freeze
  # Monto mínimo razonable en COP (Fase 5.11): evita registros por error
  MONTO_MINIMO = 1_000

  belongs_to :membresia
  belongs_to :registrado_por, class_name: "User"
  belongs_to :anulado_por, class_name: "User", optional: true

  validates :metodo, inclusion: { in: METODOS }
  validates :monto, numericality: { greater_than: MONTO_MINIMO,
                                    message: "debe ser mayor a $#{MONTO_MINIMO} COP" }
  validates :fecha_pago, :periodo_inicio, :periodo_fin, presence: true
  # Historial AUDITABLE (SDD §08, Fase 5.11): un pago se corrige o se anula
  # dejando rastro, nunca se borra; y una vez anulado ya no se toca.
  validate :anulado_no_se_edita, on: :update

  scope :vigentes, -> { where(anulado_en: nil) }

  def anulado? = anulado_en.present?

  # "Eliminar" un pago = anularlo: sigue en el historial marcado como eliminado.
  def anular!(por:)
    update!(anulado_en: Time.current, anulado_por: por)
  end

  private
    def anulado_no_se_edita
      errors.add(:base, "Un pago eliminado no se puede modificar") if anulado_en_was.present?
    end
end
