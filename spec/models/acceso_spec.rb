require "rails_helper"

RSpec.describe Acceso, type: :model do
  it "primer acceso dentro del período es checkin" do
    # Hora fija dentro de la franja 06:00–22:00 (el test no depende del reloj)
    acceso = Acceso.registrar_para(users(:one), membresias(:activa_one), ahora: Time.current.change(hour: 10))
    expect(acceso.tipo).to eq("checkin")
    expect(acceso.dentro_de_horario?).to be_truthy
  end

  it "acceso tras renovación (último acceso anterior al período) es reingreso" do
    user = users(:two)
    membresia = membresias(:vencida_two)
    user.accesos.create!(fecha_hora: membresia.fecha_inicio - 5.days, tipo: "checkin")
    membresia.renovar!(monto: 80_000, metodo: "efectivo", registrado_por: users(:admin))

    acceso = Acceso.registrar_para(user, membresia.reload)
    expect(acceso.tipo).to eq("reingreso")
  end

  it "marca fuera de horario según la franja de la membresía" do
    fuera = Time.current.change(hour: 23, min: 30)
    acceso = Acceso.registrar_para(users(:one), membresias(:activa_one), ahora: fuera)
    expect(acceso.dentro_de_horario?).to be_falsey
  end
end
