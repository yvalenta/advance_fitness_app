require "rails_helper"

RSpec.describe ApplicationPolicy, type: :model do
  let(:user) { users(:one) }

  it "defaults son restrictivos (fail-closed)" do
    policy = ApplicationPolicy.new(user, Object.new)
    expect(policy.index?).to be_falsey
    expect(policy.show?).to be_falsey
    expect(policy.create?).to be_falsey
    expect(policy.update?).to be_falsey
    expect(policy.destroy?).to be_falsey
    expect(policy.new?).to eq(policy.create?)
    expect(policy.edit?).to eq(policy.update?)
  end

  it "Scope base lanza NoMethodError si no se sobrescribe" do
    expect {
      ApplicationPolicy::Scope.new(user, User).resolve
    }.to raise_error(NoMethodError, /#resolve/)
  end

  describe "#del_tenant" do
    let(:tenant_af) { tenants(:advance_fitness) }
    let(:tenant_mp) { tenants(:megaplex) }

    it "solo devuelve registros cuyo user pertenece al tenant del usuario" do
      admin_mp = User.create!(email_address: "admin-mp@x.com", password: "clave1234",
                              rol: "admin", tenant: tenant_mp, nombre: "Admin MP")
      scope_klass = Class.new(ApplicationPolicy::Scope) do
        def resolve = del_tenant(scope)
      end
      resultado = scope_klass.new(users(:admin), Membresia).resolve
      expect(resultado.map { |m| m.user.tenant_id }.uniq).to eq([ tenant_af.id ])
      expect(resultado.map(&:user)).not_to include(admin_mp)
    end

    it "sin tenant_id devuelve none (defensa contra usuario global filtrando datos)" do
      superadmin = User.create!(email_address: "sa@x.com", password: "clave1234",
                                rol: "superadmin", nombre: "SA")
      scope_klass = Class.new(ApplicationPolicy::Scope) do
        def resolve = del_tenant(scope)
      end
      expect(scope_klass.new(superadmin, Membresia).resolve).to be_empty
    end
  end
end
