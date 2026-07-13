class Suscripcion < ApplicationRecord
  # "programada": esperando a que termine la suscripción activa vigente del
  # usuario para tomar su lugar (Fase 6.9) — no cuenta para el índice único
  # de "una activa por usuario", solo una lógica a nivel de aplicación.
  ESTADOS = %w[activa programada cancelada expirada].freeze
  # Si al pagar la membresía el monto cubre (al menos) el precio del plan
  # Personalizado, se considera "combo" e incluye la suscripción sin cobro
  # aparte (Fase 6.9).
  MONTO_INCLUYE_PERSONALIZADO = ->(monto) { monto.to_i >= Negocio.precio_personalizado }

  belongs_to :user
  belongs_to :plan
  # Presente solo en la suscripción incluida automáticamente con una
  # membresía "combo" — enlaza a esa membresía y distingue de una compra
  # aparte en recepción (admin/suscripciones).
  belongs_to :membresia, optional: true

  validates :estado, inclusion: { in: ESTADOS }
  validates :fecha_inicio, presence: true
  validates :user_id, uniqueness: { conditions: -> { where(estado: "activa") },
                                    message: "ya tiene una suscripción activa" },
                      if: -> { estado == "activa" }
  validates :user_id, uniqueness: { conditions: -> { where(estado: "programada") },
                                    message: "ya tiene una suscripción programada" },
                      if: -> { estado == "programada" }

  scope :activas, -> { where(estado: "activa") }
  scope :programadas, -> { where(estado: "programada") }

  def activa? = estado == "activa"
  def programada? = estado == "programada"
  def incluida_en_membresia? = membresia_id.present?

  def cancelar!
    update!(estado: "cancelada", fecha_fin: [ fecha_fin, Date.current ].compact.min)
  end

  # Membresía "combo" (Fase 6.9): si el monto pagado cubre el plan Personalizado,
  # se incluye sin cobro aparte. Si el usuario ya tiene una suscripción activa,
  # no se duplica — se programa para tomar el lugar de esa al terminar (o, si
  # la activa no tiene fecha de fin, ya está cubierto y no hace falta nada).
  def self.incluir_con_membresia!(membresia)
    ultimo_pago = membresia.pagos.order(:fecha_pago, :id).last
    return unless MONTO_INCLUYE_PERSONALIZADO.call(ultimo_pago&.monto)

    user = membresia.user
    return if user.suscripciones.programadas.exists?

    activa = user.suscripcion_activa
    if activa.nil?
      create!(user: user, plan: Plan.personalizado, membresia: membresia,
              estado: "activa", fecha_inicio: Date.current)
    elsif activa.fecha_fin.present?
      # Ya tiene una activa con fin definido: se programa para el día
      # siguiente sin cortarla. Si no tiene fecha de fin (indefinida), ya
      # está cubierto y no hace falta crear nada.
      create!(user: user, plan: Plan.personalizado, membresia: membresia,
              estado: "programada", fecha_inicio: activa.fecha_fin + 1.day)
    end
  end

  # Job recurrente (Fase 6.9): activa las programadas cuyo turno ya llegó,
  # cerrando la anterior activa del mismo usuario si seguía abierta.
  def self.activar_programadas!
    programadas.where(fecha_inicio: ..Date.current).find_each do |programada|
      transaction do
        programada.user.suscripciones.activas.where.not(id: programada.id).find_each do |anterior|
          anterior.update!(estado: "expirada", fecha_fin: anterior.fecha_fin || Date.current - 1.day)
        end
        programada.update!(estado: "activa")
      end
    end
  end
end
