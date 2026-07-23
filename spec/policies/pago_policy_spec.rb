require "rails_helper"

RSpec.describe PagoPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:entrenador) { users(:entrenador) }
  let(:admin) { users(:admin) }
  let(:pago) { pagos(:inicial_one) }

  it "index?: solo staff" do
    expect(PagoPolicy.new(dueno, Pago).index?).to be false
    expect(PagoPolicy.new(entrenador, Pago).index?).to be true
  end

  it "show?: dueño de la membresía o staff" do
    expect(PagoPolicy.new(dueno, pago).show?).to be true
    expect(PagoPolicy.new(otro, pago).show?).to be false
    expect(PagoPolicy.new(entrenador, pago).show?).to be true
  end

  it "create?: solo admin (registra pagos)" do
    expect(PagoPolicy.new(entrenador, pago).create?).to be false
    expect(PagoPolicy.new(admin, pago).create?).to be true
  end

  it "update/destroy?: solo admin y si no está anulado (auditoría append-only)" do
    expect(PagoPolicy.new(admin, pago).update?).to be true
    expect(PagoPolicy.new(admin, pago).destroy?).to be true

    pago.anular!(por: admin)
    expect(PagoPolicy.new(admin, pago).update?).to be false
    expect(PagoPolicy.new(admin, pago).destroy?).to be false
  end
end
