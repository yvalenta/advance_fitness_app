class Membresia < ApplicationRecord
  ESTADOS = %w[activa vencida suspendida].freeze
  DURACION_PERIODO = 1.month

  belongs_to :user
  has_many :pagos, dependent: :restrict_with_error

  validates :estado, inclusion: { in: ESTADOS }
  validates :fecha_inicio, :fecha_vencimiento, presence: true
  validate :vencimiento_posterior_al_inicio

  scope :activas, -> { where(estado: "activa") }
  scope :para_vencer, -> { where(estado: "activa").where(fecha_vencimiento: ...Date.current) }

  def activa? = estado == "activa"
  def vencida? = estado == "vencida"

  def dias_restantes
    (fecha_vencimiento - Date.current).to_i
  end

  # Renovación (SDD flujo D): crea el pago y extiende el vencimiento un
  # período desde hoy o desde el vencimiento vigente, lo que sea mayor.
  def renovar!(monto:, metodo:, registrado_por:)
    transaction do
      base = [ fecha_vencimiento, Date.current ].max
      nuevo_vencimiento = base + DURACION_PERIODO

      pagos.create!(
        monto: monto,
        metodo: metodo,
        registrado_por: registrado_por,
        fecha_pago: Date.current,
        periodo_inicio: base,
        periodo_fin: nuevo_vencimiento
      )
      update!(fecha_vencimiento: nuevo_vencimiento, estado: "activa")
    end
  end

  # El formulario admin captura una franja única (apertura/cierre) que se
  # aplica a todos los días; vacía = sin restricción de horario.
  def hora_apertura = horario_acceso&.dig("lun", 0)
  def hora_cierre = horario_acceso&.dig("lun", 1)

  def aplicar_horario(apertura, cierre)
    self.horario_acceso =
      if apertura.present? && cierre.present?
        HorarioAcceso::DIAS.index_with { [ apertura, cierre ] }
      end
  end

  private
    def vencimiento_posterior_al_inicio
      return if fecha_inicio.blank? || fecha_vencimiento.blank?
      errors.add(:fecha_vencimiento, "debe ser posterior a la fecha de inicio") if fecha_vencimiento <= fecha_inicio
    end
end
