require "test_helper"

class PagoTest < ActiveSupport::TestCase
  # Fase 5.11: historial auditable — montos razonables, anulación con rastro.
  test "el monto debe ser mayor a 1000 COP" do
    pago = pagos(:inicial_one)
    pago.monto = 1000
    assert_not pago.valid?
    assert_match(/mayor a \$1000/, pago.errors[:monto].to_sentence)
  end

  test "anular! deja el pago en el historial marcado como eliminado" do
    pago = pagos(:inicial_one)

    assert_no_difference "Pago.count" do
      pago.anular!(por: users(:admin))
    end
    assert pago.reload.anulado?
    assert_equal users(:admin), pago.anulado_por
    assert_not_includes Pago.vigentes, pago
  end

  test "un pago anulado ya no se puede modificar" do
    pago = pagos(:inicial_one)
    pago.anular!(por: users(:admin))

    pago.monto = 99_000
    assert_not pago.valid?
    assert_match(/eliminado no se puede modificar/, pago.errors[:base].to_sentence)
  end

  test "un pago vigente sí se puede corregir" do
    pago = pagos(:inicial_one)
    assert pago.update(monto: 85_000, metodo: "transferencia")
  end
end
