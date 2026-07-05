require "test_helper"

class HorarioAccesoTest < ActiveSupport::TestCase
  HORARIO = { "lun" => [ "06:00", "22:00" ] }.freeze

  test "sin horario configurado no hay restricción" do
    assert HorarioAcceso.dentro?(nil)
    assert HorarioAcceso.dentro?({})
  end

  test "sin franja para el día no hay restricción" do
    domingo = Time.zone.parse("2026-07-05 10:00") # domingo
    assert HorarioAcceso.dentro?(HORARIO, domingo)
  end

  test "valida dentro y fuera de la franja del día" do
    lunes_ok = Time.zone.parse("2026-07-06 10:00")
    lunes_temprano = Time.zone.parse("2026-07-06 05:30")
    lunes_tarde = Time.zone.parse("2026-07-06 22:30")

    assert HorarioAcceso.dentro?(HORARIO, lunes_ok)
    assert_not HorarioAcceso.dentro?(HORARIO, lunes_temprano)
    assert_not HorarioAcceso.dentro?(HORARIO, lunes_tarde)
  end
end
