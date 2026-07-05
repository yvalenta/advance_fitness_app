# Valida el horario de acceso de una membresía (SDD §07):
#   { "lun" => ["06:00", "22:00"], "mar" => ["06:00", "22:00"], ... }
# Sin horario configurado (o sin franja para el día) no hay restricción.
module HorarioAcceso
  DIAS = %w[dom lun mar mie jue vie sab].freeze

  def self.dentro?(horario, momento = Time.current)
    return true if horario.blank?

    franja = horario[DIAS[momento.wday]]
    return true if franja.blank?

    desde, hasta = franja
    hora = momento.strftime("%H:%M")
    hora >= desde && hora <= hasta
  end
end
