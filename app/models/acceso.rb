class Acceso < ApplicationRecord
  TIPOS = %w[checkin reingreso].freeze

  belongs_to :user

  validates :tipo, inclusion: { in: TIPOS }
  validates :fecha_hora, presence: true

  scope :recientes, -> { order(fecha_hora: :desc) }

  # Registra el check-in del miembro (SDD flujo D). Es "reingreso" cuando
  # el usuario ya tenía accesos pero ninguno dentro del período vigente de
  # su membresía — volvió después de una renovación.
  def self.registrar_para(user, membresia, ahora: Time.current)
    ultimo = user.accesos.recientes.first
    tipo =
      if ultimo && membresia && ultimo.fecha_hora.to_date < membresia.fecha_inicio
        "reingreso"
      else
        "checkin"
      end

    user.accesos.create!(
      fecha_hora: ahora,
      tipo: tipo,
      dentro_de_horario: HorarioAcceso.dentro?(membresia&.horario_acceso, ahora)
    )
  end
end
