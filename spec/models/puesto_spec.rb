require "rails_helper"

RSpec.describe Puesto, type: :model do
  let(:user) { users(:one) }
  let(:tenant) { tenants(:advance_fitness) }
  let(:otro_tenant) { tenants(:megaplex) }

  it "acepta un segundo puesto del mismo user en OTRO tenant (la pieza N:M)" do
    # users(:one) ya tiene su puesto en advance_fitness por fixture: esta es
    # exactamente la situación del dueño de dos gimnasios con UNA cuenta.
    puesto = Puesto.new(user: user, tenant: otro_tenant, rol: "admin")
    expect(puesto).to be_valid
  end

  it "rechaza un segundo puesto en el mismo (user, tenant)" do
    duplicado = Puesto.new(user: user, tenant: tenant, rol: "entrenador")
    expect(duplicado).not_to be_valid
    expect(duplicado.errors[:user_id]).to be_present
  end

  it "el único de la base respalda la unicidad ante una carrera" do
    duplicado = Puesto.new(user: user, tenant: tenant, rol: "entrenador")
    expect { duplicado.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "acepta los roles de tenant y rechaza los globales y los inventados" do
    (User::ROLES - User::ROLES_GLOBALES).each do |rol|
      expect(Puesto.new(user: user, tenant: otro_tenant, rol: rol)).to be_valid
    end

    User::ROLES_GLOBALES.each do |rol|
      puesto = Puesto.new(user: user, tenant: otro_tenant, rol: rol)
      expect(puesto).not_to be_valid
      expect(puesto.errors[:rol]).to be_present
    end

    expect(Puesto.new(user: user, tenant: otro_tenant, rol: "gerente")).not_to be_valid
  end

  # Guarda del contrato (User): la cache users.tenant_id/rol debe tener su
  # fila de verdad en puestos — las fixtures reflejan lo que el backfill
  # garantiza en producción.
  it "cada user de fixture con tenant tiene su puesto con el mismo rol" do
    User.where.not(tenant_id: nil).where.not(rol: User::ROLES_GLOBALES).find_each do |u|
      expect(u.puestos.exists?(tenant_id: u.tenant_id, rol: u.rol)).to be(true),
        "#{u.email_address} no tiene puesto coherente con su cache tenant/rol"
    end
  end
end
