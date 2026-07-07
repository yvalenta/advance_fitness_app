require "test_helper"

class AccesoTest < ActiveSupport::TestCase
  test "primer acceso dentro del período es checkin" do
    # Hora fija dentro de la franja 06:00–22:00 (el test no depende del reloj)
    acceso = Acceso.registrar_para(users(:one), membresias(:activa_one), ahora: Time.current.change(hour: 10))
    assert_equal "checkin", acceso.tipo
    assert acceso.dentro_de_horario?
  end

  test "acceso tras renovación (último acceso anterior al período) es reingreso" do
    user = users(:two)
    membresia = membresias(:vencida_two)
    user.accesos.create!(fecha_hora: membresia.fecha_inicio - 5.days, tipo: "checkin")
    membresia.renovar!(monto: 80_000, metodo: "efectivo", registrado_por: users(:admin))

    acceso = Acceso.registrar_para(user, membresia.reload)
    assert_equal "reingreso", acceso.tipo
  end

  test "marca fuera de horario según la franja de la membresía" do
    fuera = Time.current.change(hour: 23, min: 30)
    acceso = Acceso.registrar_para(users(:one), membresias(:activa_one), ahora: fuera)
    assert_not acceso.dentro_de_horario?
  end
end
