require "rails_helper"

RSpec.describe LogroPolicy, type: :model do
  let(:miembro) { users(:one) }
  let(:admin) { users(:admin) }
  let(:entrenador) { users(:entrenador) }
  let(:global) do
    Logro.create!(codigo: "primera-sesion", nombre: "Primera sesión",
                  puntos: 20, categoria: "constancia")
  end
  let(:del_tenant) do
    Logro.create!(codigo: "reto-agosto", nombre: "Reto de agosto", puntos: 50,
                  categoria: "constancia", tenant: tenants(:advance_fitness))
  end
  let(:de_otro_tenant) do
    Logro.create!(codigo: "reto-mp", nombre: "Reto MP", puntos: 50,
                  categoria: "constancia", tenant: tenants(:megaplex))
  end

  it "catálogo visible para todos" do
    expect(LogroPolicy.new(miembro, global).index?).to be true
    expect(LogroPolicy.new(miembro, global).show?).to be true
  end

  it "create?: solo admin" do
    expect(LogroPolicy.new(miembro, Logro.new).create?).to be false
    expect(LogroPolicy.new(entrenador, Logro.new).create?).to be false
    expect(LogroPolicy.new(admin, Logro.new).create?).to be true
  end

  it "update?/destroy?: admin solo sobre los de SU tenant — los globales no se tocan" do
    expect(LogroPolicy.new(admin, del_tenant).update?).to be true
    expect(LogroPolicy.new(admin, del_tenant).destroy?).to be true
    expect(LogroPolicy.new(admin, global).update?).to be false
    expect(LogroPolicy.new(admin, de_otro_tenant).update?).to be false
    expect(LogroPolicy.new(miembro, del_tenant).update?).to be false
  end

  it "Scope: catálogo global + los del propio tenant, nunca los de otro" do
    global; del_tenant; de_otro_tenant
    expect(LogroPolicy::Scope.new(miembro, Logro).resolve).to contain_exactly(global, del_tenant)
    expect(LogroPolicy::Scope.new(admin, Logro).resolve).to contain_exactly(global, del_tenant)
  end
end
