require "rails_helper"

RSpec.describe MedicionPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:admin) { users(:admin) }
  let(:medicion_propia) { Medicion.create!(user: dueno, fecha: Date.current, peso_kg: 70) }
  let(:medicion_ajena) { Medicion.create!(user: otro, fecha: Date.current, peso_kg: 72) }

  it "index/new/edit/update: solo staff" do
    expect(MedicionPolicy.new(dueno, Medicion).index?).to be false
    expect(MedicionPolicy.new(dueno, medicion_propia).edit?).to be false
    expect(MedicionPolicy.new(admin, medicion_propia).edit?).to be true
    expect(MedicionPolicy.new(admin, medicion_propia).update?).to be true
  end

  it "create?: staff o el propio miembro (auto-registro de peso, Fase 5.9)" do
    expect(MedicionPolicy.new(dueno, medicion_propia).create?).to be true
    expect(MedicionPolicy.new(otro, medicion_propia).create?).to be false
    expect(MedicionPolicy.new(admin, medicion_ajena).create?).to be true
  end
end
