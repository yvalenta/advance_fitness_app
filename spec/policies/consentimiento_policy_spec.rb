require "rails_helper"

RSpec.describe ConsentimientoPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:admin) { users(:admin) }
  let(:propio) do
    Consentimiento.create!(user: dueno, tipo: "tabla_posiciones",
                           accion: "otorgado", version_texto: "v1")
  end

  it "create?: solo el propio usuario — ni el staff consiente por otros" do
    expect(ConsentimientoPolicy.new(dueno, propio).create?).to be true
    expect(ConsentimientoPolicy.new(otro, propio).create?).to be false
    expect(ConsentimientoPolicy.new(admin, propio).create?).to be false
  end

  it "show?: solo el propio usuario — el staff NO lee los de otros" do
    expect(ConsentimientoPolicy.new(dueno, propio).show?).to be true
    expect(ConsentimientoPolicy.new(otro, propio).show?).to be false
    expect(ConsentimientoPolicy.new(admin, propio).show?).to be false
  end

  it "nadie edita ni borra (append-only)" do
    expect(ConsentimientoPolicy.new(dueno, propio).update?).to be false
    expect(ConsentimientoPolicy.new(dueno, propio).destroy?).to be false
    expect(ConsentimientoPolicy.new(admin, propio).update?).to be false
    expect(ConsentimientoPolicy.new(admin, propio).destroy?).to be false
  end

  it "Scope: cada quien ve SOLO los suyos, incluso el staff" do
    propio
    expect(ConsentimientoPolicy::Scope.new(dueno, Consentimiento).resolve).to contain_exactly(propio)
    expect(ConsentimientoPolicy::Scope.new(otro, Consentimiento).resolve).to be_empty
    expect(ConsentimientoPolicy::Scope.new(admin, Consentimiento).resolve).to be_empty
  end
end
