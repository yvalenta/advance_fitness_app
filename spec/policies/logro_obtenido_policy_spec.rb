require "rails_helper"

RSpec.describe LogroObtenidoPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:admin) { users(:admin) }
  let(:logro) do
    Logro.create!(codigo: "primera-sesion", nombre: "Primera sesión",
                  puntos: 20, categoria: "constancia")
  end
  let(:propio) { LogroObtenido.create!(user: dueno, logro: logro, obtenido_en: Time.current) }
  let(:ajeno) { LogroObtenido.create!(user: otro, logro: logro, obtenido_en: Time.current) }

  it "show?: dueño o staff" do
    expect(LogroObtenidoPolicy.new(dueno, propio).show?).to be true
    expect(LogroObtenidoPolicy.new(otro, propio).show?).to be false
    expect(LogroObtenidoPolicy.new(admin, propio).show?).to be true
  end

  it "nadie crea, edita ni borra a mano: los otorga el motor" do
    expect(LogroObtenidoPolicy.new(admin, propio).create?).to be false
    expect(LogroObtenidoPolicy.new(admin, propio).update?).to be false
    expect(LogroObtenidoPolicy.new(admin, propio).destroy?).to be false
  end

  it "Scope: miembro ve lo suyo; staff, su tenant" do
    propio; ajeno
    expect(LogroObtenidoPolicy::Scope.new(dueno, LogroObtenido).resolve).to contain_exactly(propio)
    expect(LogroObtenidoPolicy::Scope.new(admin, LogroObtenido).resolve).to contain_exactly(propio, ajeno)
  end
end
