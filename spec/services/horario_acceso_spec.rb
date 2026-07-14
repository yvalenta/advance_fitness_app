require "rails_helper"

RSpec.describe HorarioAcceso, type: :model do
  HORARIO = { "lun" => [ "06:00", "22:00" ] }.freeze

  it "sin horario configurado no hay restricción" do
    expect(HorarioAcceso.dentro?(nil)).to be_truthy
    expect(HorarioAcceso.dentro?({})).to be_truthy
  end

  it "sin franja para el día no hay restricción" do
    domingo = Time.zone.parse("2026-07-05 10:00") # domingo
    expect(HorarioAcceso.dentro?(HORARIO, domingo)).to be_truthy
  end

  it "valida dentro y fuera de la franja del día" do
    lunes_ok = Time.zone.parse("2026-07-06 10:00")
    lunes_temprano = Time.zone.parse("2026-07-06 05:30")
    lunes_tarde = Time.zone.parse("2026-07-06 22:30")

    expect(HorarioAcceso.dentro?(HORARIO, lunes_ok)).to be_truthy
    expect(HorarioAcceso.dentro?(HORARIO, lunes_temprano)).to be_falsey
    expect(HorarioAcceso.dentro?(HORARIO, lunes_tarde)).to be_falsey
  end
end
