require "test_helper"

class SuscripcionTest < ActiveSupport::TestCase
  test "solo una suscripción activa por usuario" do
    Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    duplicada = Suscripcion.new(user: users(:one), plan: planes(:free), estado: "activa", fecha_inicio: Date.current)

    assert_not duplicada.valid?
  end

  test "cancelar! cambia el estado y cierra la fecha de fin" do
    suscripcion = Suscripcion.create!(user: users(:one), plan: planes(:personalizado),
                                      estado: "activa", fecha_inicio: Date.current)
    suscripcion.cancelar!

    assert_equal "cancelada", suscripcion.estado
    assert_equal Date.current, suscripcion.fecha_fin
    assert_not users(:one).premium?
  end

  test "premium? refleja la suscripción activa al plan personalizado" do
    assert_not users(:one).premium?
    Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    assert users(:one).reload.premium?
  end

  test "incluir_con_membresia! crea la suscripción activa si el monto cubre el Personalizado" do
    membresia = membresias(:activa_one)
    membresia.pagos.create!(monto: Negocio.precio_personalizado, metodo: "efectivo",
                            registrado_por: users(:entrenador), fecha_pago: Date.current,
                            periodo_inicio: Date.current, periodo_fin: Date.current + 30)

    assert_difference -> { Suscripcion.count }, 1 do
      Suscripcion.incluir_con_membresia!(membresia)
    end

    suscripcion = membresia.user.suscripcion_activa
    assert suscripcion.activa?
    assert suscripcion.incluida_en_membresia?
    assert_equal membresia, suscripcion.membresia
    assert_equal planes(:personalizado), suscripcion.plan
  end

  test "incluir_con_membresia! no hace nada si el monto no cubre el Personalizado" do
    membresia = membresias(:activa_one) # su pago fixture es de 80.000

    assert_no_difference -> { Suscripcion.count } do
      Suscripcion.incluir_con_membresia!(membresia)
    end
  end

  test "incluir_con_membresia! programa la siguiente si ya hay una activa con fin" do
    membresia = membresias(:activa_one)
    membresia.pagos.create!(monto: Negocio.precio_personalizado, metodo: "efectivo",
                            registrado_por: users(:entrenador), fecha_pago: Date.current,
                            periodo_inicio: Date.current, periodo_fin: Date.current + 30)
    activa = Suscripcion.create!(user: membresia.user, plan: planes(:personalizado),
                                estado: "activa", fecha_inicio: Date.current - 10, fecha_fin: Date.current + 5)

    assert_difference -> { Suscripcion.count }, 1 do
      Suscripcion.incluir_con_membresia!(membresia)
    end

    programada = membresia.user.suscripciones.programadas.first
    assert_equal activa.fecha_fin + 1.day, programada.fecha_inicio
    assert programada.incluida_en_membresia?
  end

  test "incluir_con_membresia! no duplica si ya hay una activa sin fecha de fin" do
    membresia = membresias(:activa_one)
    membresia.pagos.create!(monto: Negocio.precio_personalizado, metodo: "efectivo",
                            registrado_por: users(:entrenador), fecha_pago: Date.current,
                            periodo_inicio: Date.current, periodo_fin: Date.current + 30)
    Suscripcion.create!(user: membresia.user, plan: planes(:personalizado),
                       estado: "activa", fecha_inicio: Date.current - 10)

    assert_no_difference -> { Suscripcion.count } do
      Suscripcion.incluir_con_membresia!(membresia)
    end
  end

  test "activar_programadas! activa las que llegaron su turno y expira la anterior" do
    membresia = membresias(:activa_one)
    anterior = Suscripcion.create!(user: membresia.user, plan: planes(:personalizado), estado: "activa",
                                  fecha_inicio: Date.current - 10, fecha_fin: Date.current - 1)
    programada = Suscripcion.create!(user: membresia.user, plan: planes(:personalizado), membresia: membresia,
                                    estado: "programada", fecha_inicio: Date.current)

    Suscripcion.activar_programadas!

    assert_equal "activa", programada.reload.estado
    assert_equal "expirada", anterior.reload.estado
  end
end
