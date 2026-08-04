require "rails_helper"

RSpec.describe RecordPersonalPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:admin) { users(:admin) }
  let(:ejercicio) do
    Ejercicio.create!(dataset_id: "test-pr-pol-01", nombre: "Sentadilla", nombre_en: "Squat",
                      nombre_normalizado: "sentadilla", categoria: "fuerza", musculo: "pierna")
  end
  let(:propio) do
    RecordPersonal.create!(user: dueno, ejercicio: ejercicio, tipo: "peso_max",
                           valor: 80, fecha: Date.current)
  end
  let(:ajeno) do
    RecordPersonal.create!(user: otro, ejercicio: ejercicio, tipo: "peso_max",
                           valor: 90, fecha: Date.current)
  end

  it "show?: dueño o staff" do
    expect(RecordPersonalPolicy.new(dueno, propio).show?).to be true
    expect(RecordPersonalPolicy.new(otro, propio).show?).to be false
    expect(RecordPersonalPolicy.new(admin, propio).show?).to be true
  end

  it "nadie crea desde la UI ni edita ni borra (histórico: solo escribe el detector)" do
    [ dueno, admin ].each do |quien|
      policy = RecordPersonalPolicy.new(quien, propio)
      expect(policy.create?).to be false
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
    end
  end

  it "Scope: miembro ve lo suyo; staff, su tenant" do
    propio; ajeno
    expect(RecordPersonalPolicy::Scope.new(dueno, RecordPersonal).resolve).to contain_exactly(propio)
    expect(RecordPersonalPolicy::Scope.new(admin, RecordPersonal).resolve).to contain_exactly(propio, ajeno)
  end
end
