require "rails_helper"

RSpec.describe TenantPolicy do
  let(:tenant) { tenants(:advance_fitness) }

  it "solo superadmin puede gestionar tenants" do
    superadmin = User.create!(email_address: "sa@x.com", password: "clave1234", rol: "superadmin", nombre: "SA")
    %i[index? show? create? update?].each do |accion|
      expect(described_class.new(superadmin, tenant).public_send(accion)).to be true
    end
    expect(described_class.new(superadmin, tenant).destroy?).to be false
  end

  it "admin/entrenador/miembro/comercializador no pueden gestionar tenants" do
    [ users(:admin), users(:entrenador), users(:one),
      User.create!(email_address: "co@x.com", password: "clave1234", rol: "comercializador", nombre: "Co") ].each do |user|
      %i[index? show? create? update?].each do |accion|
        expect(described_class.new(user, tenant).public_send(accion)).to be(false), "#{user.rol} no debería poder #{accion}"
      end
    end
  end
end
