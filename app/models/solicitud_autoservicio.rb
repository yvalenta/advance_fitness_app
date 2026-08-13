# Lead del canal de autoservicio (join.ynt.codes, SDD §17.5): un entrenador
# que quiere su propio tenant, o una persona que quiere usar la app para sí
# misma sin gimnasio detrás. Sin cobro online todavía — el comercializador
# la contacta a mano y crea el tenant/usuario por el portal comercial de
# siempre (§16.6). Nunca se borra: es el historial de leads del canal.
class SolicitudAutoservicio < ApplicationRecord
  SEGMENTOS = %w[entrenador individual].freeze

  belongs_to :atendida_por, class_name: "User", optional: true

  validates :nombre, :email, :telefono, presence: true
  validates :segmento, inclusion: { in: SEGMENTOS }
  validates :negocio_nombre, presence: true, if: -> { segmento == "entrenador" }

  scope :pendientes, -> { where(atendida_en: nil) }
  scope :recientes, -> { order(created_at: :desc) }

  def atendida? = atendida_en.present?

  def marcar_atendida!(por:)
    update!(atendida_en: Time.current, atendida_por: por)
  end
end
