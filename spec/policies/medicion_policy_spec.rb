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

  # Defensa en profundidad (tarea 2026-08-31): el rol ya no basta — el DUEÑO
  # de la medición debe tener puesto en el gimnasio del staff. Este es el
  # check que frena a un controller descuidado con un find crudo.
  it "el staff de A no toca mediciones de un miembro de B, aunque sea staff" do
    miembro_mp = User.create!(email_address: "miembro-mp@x.com", password: "clave1234",
                              rol: "miembro", tenant: tenants(:megaplex), nombre: "Miembro MP")
    medicion_mp = Medicion.create!(user: miembro_mp, fecha: Date.current, peso_kg: 90)

    expect(MedicionPolicy.new(admin, medicion_mp).new?).to be false
    expect(MedicionPolicy.new(admin, medicion_mp).create?).to be false
    expect(MedicionPolicy.new(admin, medicion_mp).edit?).to be false
    expect(MedicionPolicy.new(admin, medicion_mp).update?).to be false
    # …y el propio miembro de B sigue pudiendo auto-registrarse.
    expect(MedicionPolicy.new(miembro_mp, medicion_mp).create?).to be true
  end
end
