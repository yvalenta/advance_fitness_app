require "rails_helper"

RSpec.describe RegistroPuntoPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:admin) { users(:admin) }
  let(:propio) { RegistroPunto.create!(user: dueno, tipo: "checkin", puntos: 10, fecha: Date.current) }
  let(:ajeno) { RegistroPunto.create!(user: otro, tipo: "checkin", puntos: 10, fecha: Date.current) }

  it "show?: dueño o staff" do
    expect(RegistroPuntoPolicy.new(dueno, propio).show?).to be true
    expect(RegistroPuntoPolicy.new(otro, propio).show?).to be false
    expect(RegistroPuntoPolicy.new(admin, propio).show?).to be true
  end

  it "create?: solo staff (ajuste_manual); el resto entra por jobs" do
    expect(RegistroPuntoPolicy.new(dueno, propio).create?).to be false
    expect(RegistroPuntoPolicy.new(admin, propio).create?).to be true
  end

  it "nadie edita ni borra (ledger append-only)" do
    expect(RegistroPuntoPolicy.new(admin, propio).update?).to be false
    expect(RegistroPuntoPolicy.new(admin, propio).destroy?).to be false
  end

  it "Scope: miembro ve lo suyo; staff, su tenant" do
    propio; ajeno
    expect(RegistroPuntoPolicy::Scope.new(dueno, RegistroPunto).resolve).to contain_exactly(propio)
    expect(RegistroPuntoPolicy::Scope.new(admin, RegistroPunto).resolve).to contain_exactly(propio, ajeno)
  end
end
