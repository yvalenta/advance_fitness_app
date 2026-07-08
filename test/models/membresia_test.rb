require "test_helper"

class MembresiaTest < ActiveSupport::TestCase
  test "renovar! extiende el vencimiento, activa y registra el pago" do
    membresia = membresias(:vencida_two)

    assert_difference "Pago.count", 1 do
      membresia.renovar!(monto: 80_000, metodo: "efectivo", registrado_por: users(:admin))
    end

    assert_equal "activa", membresia.estado
    assert_equal Date.current + 30.days, membresia.fecha_vencimiento

    pago = membresia.pagos.order(:id).last
    assert_equal Date.current, pago.periodo_inicio
    assert_equal membresia.fecha_vencimiento, pago.periodo_fin
  end

  test "renovar! de una activa extiende desde el vencimiento vigente" do
    membresia = membresias(:activa_one)
    vencimiento_original = membresia.fecha_vencimiento

    membresia.renovar!(monto: 80_000, metodo: "tarjeta", registrado_por: users(:admin))

    assert_equal vencimiento_original + 30.days, membresia.fecha_vencimiento
  end

  test "para_vencer solo incluye activas con fecha pasada" do
    membresias(:activa_one).update!(fecha_vencimiento: Date.current - 1, fecha_inicio: Date.current - 40)

    assert_includes Membresia.para_vencer, membresias(:activa_one)
    assert_not_includes Membresia.para_vencer, membresias(:vencida_two)
  end

  test "el vencimiento debe ser posterior al inicio" do
    membresia = Membresia.new(user: users(:admin), fecha_inicio: Date.current, fecha_vencimiento: Date.current)
    assert_not membresia.valid?
  end

  test "los pagos son inmutables" do
    pago = pagos(:inicial_one)
    assert_raises(ActiveRecord::ReadOnlyRecord) { pago.update!(monto: 1) }
  end
end
