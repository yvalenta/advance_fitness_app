require "rails_helper"

RSpec.describe PagoPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:entrenador) { users(:entrenador) }
  let(:admin) { users(:admin) }
  let(:recepcion) { users(:recepcion) }
  let(:pago) { pagos(:inicial_one) }

  it "index?: staff o mostrador" do
    expect(PagoPolicy.new(dueno, Pago).index?).to be false
    expect(PagoPolicy.new(entrenador, Pago).index?).to be true
    expect(PagoPolicy.new(recepcion, Pago).index?).to be true
  end

  it "show?: dueño de la membresía, staff o mostrador" do
    expect(PagoPolicy.new(dueno, pago).show?).to be true
    expect(PagoPolicy.new(otro, pago).show?).to be false
    expect(PagoPolicy.new(entrenador, pago).show?).to be true
    expect(PagoPolicy.new(recepcion, pago).show?).to be true
  end

  it "create?: mostrador — admin y recepción cobran; el entrenador no" do
    expect(PagoPolicy.new(entrenador, pago).create?).to be false
    expect(PagoPolicy.new(admin, pago).create?).to be true
    expect(PagoPolicy.new(recepcion, pago).create?).to be true
  end

  it "update/destroy?: solo admin y si no está anulado (auditoría append-only)" do
    expect(PagoPolicy.new(admin, pago).update?).to be true
    expect(PagoPolicy.new(admin, pago).destroy?).to be true

    pago.anular!(por: admin)
    expect(PagoPolicy.new(admin, pago).update?).to be false
    expect(PagoPolicy.new(admin, pago).destroy?).to be false
  end

  # Recepción registra el cobro pero no lo corrige ni lo anula: quien cobra
  # no borra su propio rastro. Ese arreglo es del admin, y queda firmado.
  it "recepción NO corrige ni anula pagos (ni siquiera uno vigente)" do
    expect(PagoPolicy.new(recepcion, pago).update?).to be false
    expect(PagoPolicy.new(recepcion, pago).destroy?).to be false
  end

  it "scope: recepción ve los pagos de su tenant; el miembro solo los suyos" do
    expect(PagoPolicy::Scope.new(recepcion, Pago).resolve).to include(pago)
    expect(PagoPolicy::Scope.new(otro, Pago).resolve).not_to include(pago)
  end
end
