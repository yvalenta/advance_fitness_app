require "rails_helper"

RSpec.describe ObjetivoNutricionalPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:admin) { users(:admin) }
  let(:objetivo) do
    ObjetivoNutricional.create!(user: dueno, tipo: "mantenimiento",
                                peso_kg: 70, tdee_kcal: 2200, objetivo_kcal: 2200)
  end

  it "show?/update?: solo el dueño" do
    expect(ObjetivoNutricionalPolicy.new(dueno, objetivo).show?).to be true
    expect(ObjetivoNutricionalPolicy.new(otro, objetivo).show?).to be false
    expect(ObjetivoNutricionalPolicy.new(admin, objetivo).show?).to be false
    expect(ObjetivoNutricionalPolicy.new(dueno, objetivo).update?).to be true
    expect(ObjetivoNutricionalPolicy.new(admin, objetivo).update?).to be false
  end

  it "create?: cualquier autenticado (el controller construye desde Current.user)" do
    expect(ObjetivoNutricionalPolicy.new(dueno, ObjetivoNutricional).create?).to be true
    expect(ObjetivoNutricionalPolicy.new(nil, ObjetivoNutricional).create?).to be_falsey
  end
end
