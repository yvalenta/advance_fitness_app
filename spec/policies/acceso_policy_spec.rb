require "rails_helper"

RSpec.describe AccesoPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:admin) { users(:admin) }
  let(:acceso_propio) { Acceso.create!(user: dueno, fecha_hora: Time.current) }
  let(:acceso_ajeno) { Acceso.create!(user: otro, fecha_hora: Time.current) }

  it "index? solo para staff" do
    expect(AccesoPolicy.new(dueno, Acceso).index?).to be false
    expect(AccesoPolicy.new(admin, Acceso).index?).to be true
  end

  it "show?: dueño o staff" do
    expect(AccesoPolicy.new(dueno, acceso_propio).show?).to be true
    expect(AccesoPolicy.new(otro, acceso_propio).show?).to be false
    expect(AccesoPolicy.new(admin, acceso_propio).show?).to be true
  end

  it "create?: staff o el propio miembro" do
    expect(AccesoPolicy.new(dueno, acceso_propio).create?).to be true
    expect(AccesoPolicy.new(otro, acceso_propio).create?).to be false
    expect(AccesoPolicy.new(admin, acceso_ajeno).create?).to be true
  end

  it "nadie edita ni borra (accesos son auditoría append-only)" do
    expect(AccesoPolicy.new(admin, acceso_propio).update?).to be false
    expect(AccesoPolicy.new(admin, acceso_propio).destroy?).to be false
  end
end
