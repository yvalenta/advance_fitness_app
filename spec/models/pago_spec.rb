require "rails_helper"

RSpec.describe Pago, type: :model do
  # Fase 5.11: historial auditable — montos razonables, anulación con rastro.
  it "el monto debe ser mayor a 1000 COP" do
    pago = pagos(:inicial_one)
    pago.monto = 1000
    expect(pago.valid?).to be_falsey
    expect(pago.errors[:monto].to_sentence).to match(/mayor a \$1000/)
  end

  it "anular! deja el pago en el historial marcado como eliminado" do
    pago = pagos(:inicial_one)

    expect { pago.anular!(por: users(:admin)) }.not_to change(Pago, :count)
    expect(pago.reload.anulado?).to be_truthy
    expect(pago.anulado_por).to eq(users(:admin))
    expect(Pago.vigentes).not_to include(pago)
  end

  it "un pago anulado ya no se puede modificar" do
    pago = pagos(:inicial_one)
    pago.anular!(por: users(:admin))

    pago.monto = 99_000
    expect(pago.valid?).to be_falsey
    expect(pago.errors[:base].to_sentence).to match(/eliminado no se puede modificar/)
  end

  it "un pago vigente sí se puede corregir" do
    pago = pagos(:inicial_one)
    expect(pago.update(monto: 85_000, metodo: "transferencia")).to be_truthy
  end
end
