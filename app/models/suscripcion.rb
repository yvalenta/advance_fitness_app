class Suscripcion < ApplicationRecord
  ESTADOS = %w[activa cancelada expirada].freeze

  belongs_to :user
  belongs_to :plan

  validates :estado, inclusion: { in: ESTADOS }
  validates :fecha_inicio, presence: true
  validates :user_id, uniqueness: { conditions: -> { where(estado: "activa") },
                                    message: "ya tiene una suscripción activa" },
                      if: -> { estado == "activa" }

  scope :activas, -> { where(estado: "activa") }

  def activa? = estado == "activa"

  def cancelar!
    update!(estado: "cancelada", fecha_fin: [ fecha_fin, Date.current ].compact.min)
  end
end
