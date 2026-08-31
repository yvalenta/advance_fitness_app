require "rails_helper"

RSpec.describe AccesoPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:admin) { users(:admin) }
  let(:recepcion) { users(:recepcion) }
  let(:acceso_propio) { Acceso.create!(user: dueno, fecha_hora: Time.current) }
  let(:acceso_ajeno) { Acceso.create!(user: otro, fecha_hora: Time.current) }

  it "index? para staff y mostrador" do
    expect(AccesoPolicy.new(dueno, Acceso).index?).to be false
    expect(AccesoPolicy.new(admin, Acceso).index?).to be true
    expect(AccesoPolicy.new(recepcion, Acceso).index?).to be true
  end

  it "show?: dueño, staff o mostrador" do
    expect(AccesoPolicy.new(dueno, acceso_propio).show?).to be true
    expect(AccesoPolicy.new(otro, acceso_propio).show?).to be false
    expect(AccesoPolicy.new(admin, acceso_propio).show?).to be true
    expect(AccesoPolicy.new(recepcion, acceso_propio).show?).to be true
  end

  it "create?: staff, mostrador o el propio miembro" do
    expect(AccesoPolicy.new(dueno, acceso_propio).create?).to be true
    expect(AccesoPolicy.new(otro, acceso_propio).create?).to be false
    expect(AccesoPolicy.new(admin, acceso_ajeno).create?).to be true
  end

  # El check-in ES la tarea de recepción (Flujo D del SDD): registra el
  # acceso de cualquier miembro del gimnasio, no solo el suyo.
  it "recepción registra el check-in de cualquier miembro" do
    expect(AccesoPolicy.new(recepcion, acceso_propio).create?).to be true
    expect(AccesoPolicy.new(recepcion, acceso_ajeno).create?).to be true
  end

  it "recepción tampoco edita ni borra accesos (append-only para todos)" do
    expect(AccesoPolicy.new(recepcion, acceso_propio).update?).to be false
    expect(AccesoPolicy.new(recepcion, acceso_propio).destroy?).to be false
  end

  it "scope: recepción ve los accesos de su tenant; el miembro solo los suyos" do
    acceso_propio
    acceso_ajeno
    expect(AccesoPolicy::Scope.new(recepcion, Acceso).resolve)
      .to include(acceso_propio, acceso_ajeno)
    expect(AccesoPolicy::Scope.new(dueno, Acceso).resolve).not_to include(acceso_ajeno)
  end

  it "nadie edita ni borra (accesos son auditoría append-only)" do
    expect(AccesoPolicy.new(admin, acceso_propio).update?).to be false
    expect(AccesoPolicy.new(admin, acceso_propio).destroy?).to be false
  end

  # Defensa en profundidad (tarea 2026-08-31): registrar o ver un acceso
  # exige que el miembro tenga puesto en el gimnasio del viewer — el rol de
  # staff/mostrador solo ya no basta ante un find crudo.
  it "ni el admin ni recepción de A registran o ven el check-in de un miembro de B" do
    miembro_mp = User.create!(email_address: "miembro-mp@x.com", password: "clave1234",
                              rol: "miembro", tenant: tenants(:megaplex), nombre: "Miembro MP")
    acceso_mp = Acceso.new(user: miembro_mp)

    expect(AccesoPolicy.new(admin, acceso_mp).create?).to be false
    expect(AccesoPolicy.new(recepcion, acceso_mp).create?).to be false
    expect(AccesoPolicy.new(admin, Acceso.create!(user: miembro_mp, fecha_hora: Time.current)).show?).to be false
    # …y el propio miembro de B sigue pudiendo auto-registrarse.
    expect(AccesoPolicy.new(miembro_mp, acceso_mp).create?).to be true
  end
end
