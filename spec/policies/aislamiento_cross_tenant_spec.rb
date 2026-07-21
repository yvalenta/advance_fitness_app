require "rails_helper"

# El test más crítico de multi-tenancy (SDD §16.6): garantiza que el `Scope`
# de una policy jamás incluye registros de otro tenant, incluso cuando el
# usuario es staff (que antes veía `scope.all` sin filtro).
RSpec.describe "Aislamiento cross-tenant en policies", type: :model do
  let(:tenant_af) { tenants(:advance_fitness) }
  let(:tenant_mp) { tenants(:megaplex) }

  let(:admin_af) { users(:admin) }  # ya está en AF por fixture
  let(:admin_mp) do
    User.create!(email_address: "admin-mp@x.com", password: "clave1234",
                 rol: "admin", tenant: tenant_mp, nombre: "Admin MP")
  end

  let(:miembro_mp) do
    User.create!(email_address: "miembro-mp@x.com", password: "clave1234",
                 rol: "miembro", tenant: tenant_mp, nombre: "Miembro MP")
  end

  it "UserPolicy::Scope solo incluye users del mismo tenant" do
    admin_mp; miembro_mp # crear
    scope_af = UserPolicy::Scope.new(admin_af, User).resolve
    scope_mp = UserPolicy::Scope.new(admin_mp, User).resolve

    expect(scope_af.pluck(:tenant_id).uniq).to eq([ tenant_af.id ])
    expect(scope_mp.pluck(:tenant_id).uniq).to eq([ tenant_mp.id ])
    expect(scope_mp).not_to include(admin_af)
  end

  it "MembresiaPolicy::Scope aísla por tenant vía user" do
    membresia_af = membresias(:activa_one)
    membresia_mp = Membresia.create!(user: miembro_mp, estado: "activa",
                                     fecha_inicio: Date.current,
                                     fecha_vencimiento: Date.current + 30)

    scope_af = MembresiaPolicy::Scope.new(admin_af, Membresia).resolve
    scope_mp = MembresiaPolicy::Scope.new(admin_mp, Membresia).resolve

    expect(scope_af).to include(membresia_af)
    expect(scope_af).not_to include(membresia_mp)
    expect(scope_mp).to include(membresia_mp)
    expect(scope_mp).not_to include(membresia_af)
  end

  it "AccesoPolicy::Scope aísla por tenant vía user" do
    acceso_af = Acceso.create!(user: users(:one), fecha_hora: Time.current)
    acceso_mp = Acceso.create!(user: miembro_mp, fecha_hora: Time.current)

    scope_af = AccesoPolicy::Scope.new(admin_af, Acceso).resolve
    scope_mp = AccesoPolicy::Scope.new(admin_mp, Acceso).resolve

    expect(scope_af).to include(acceso_af)
    expect(scope_af).not_to include(acceso_mp)
    expect(scope_mp).to include(acceso_mp)
    expect(scope_mp).not_to include(acceso_af)
  end

  it "PagoPolicy::Scope aísla por tenant vía membresia → user" do
    membresia_af = membresias(:activa_one)
    pago_af = pagos(:inicial_one)  # asociado a activa_one

    membresia_mp = Membresia.create!(user: miembro_mp, estado: "activa",
                                     fecha_inicio: Date.current,
                                     fecha_vencimiento: Date.current + 30)
    pago_mp = membresia_mp.pagos.create!(monto: 80_000, metodo: "efectivo",
                                         registrado_por: admin_mp, fecha_pago: Date.current,
                                         periodo_inicio: Date.current, periodo_fin: Date.current + 30)

    scope_af = PagoPolicy::Scope.new(admin_af, Pago).resolve
    scope_mp = PagoPolicy::Scope.new(admin_mp, Pago).resolve

    expect(scope_af).to include(pago_af)
    expect(scope_af).not_to include(pago_mp)
    expect(scope_mp).to include(pago_mp)
    expect(scope_mp).not_to include(pago_af)
  end
end
