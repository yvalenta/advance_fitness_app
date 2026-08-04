require "rails_helper"

# Contrato del concern `TenantDesnormalizado` (SDD §16.7, Etapa 1.3) sobre los
# tres modelos que lo incluyen. Es la mitad "no se puede crear una fila
# incoherente" de la defensa; la otra mitad (los Pundit Scopes fail-closed)
# vive en spec/policies/aislamiento_cross_tenant_spec.rb.
RSpec.describe TenantDesnormalizado, type: :model do
  let(:tenant_af) { tenants(:advance_fitness) }
  let(:tenant_mp) { tenants(:megaplex) }
  let(:miembro_af) { users(:one) }

  let(:miembro_mp) do
    User.create!(email_address: "miembro-mp@x.com", password: "clave1234",
                 rol: "miembro", tenant: tenant_mp, nombre: "Miembro MP")
  end

  def nueva_membresia(user, **extra)
    Membresia.new(user: user, estado: "activa", fecha_inicio: Date.current,
                  fecha_vencimiento: Date.current + 30, **extra)
  end

  describe "herencia del tenant del dueño" do
    it "Membresia lo hereda de su user sin que el controller lo pase" do
      membresia = nueva_membresia(miembro_mp)
      expect(membresia).to be_valid
      expect(membresia.tenant_id).to eq(tenant_mp.id)
    end

    it "Suscripcion lo hereda de su user" do
      suscripcion = Suscripcion.new(user: miembro_mp, plan: planes(:free),
                                    estado: "activa", fecha_inicio: Date.current)
      expect(suscripcion).to be_valid
      expect(suscripcion.tenant_id).to eq(tenant_mp.id)
    end

    it "Pago lo hereda de su membresía (no de membresia.user: un salto menos)" do
      membresia = nueva_membresia(miembro_mp)
      membresia.save!
      pago = membresia.pagos.new(monto: 80_000, metodo: "efectivo",
                                 registrado_por: miembro_mp, fecha_pago: Date.current,
                                 periodo_inicio: Date.current, periodo_fin: Date.current + 30)
      expect(pago).to be_valid
      expect(pago.tenant_id).to eq(tenant_mp.id)
    end
  end

  describe "rechazo de filas incoherentes" do
    it "no persiste una Membresia cuyo tenant_id no es el de su user" do
      membresia = nueva_membresia(miembro_af, tenant_id: tenant_mp.id)
      expect(membresia).not_to be_valid
      expect(membresia.errors[:tenant_id]).to be_present
    end

    it "no persiste una Suscripcion con tenant_id inyectado de otro tenant" do
      suscripcion = Suscripcion.new(user: miembro_af, plan: planes(:free),
                                    estado: "activa", fecha_inicio: Date.current,
                                    tenant_id: tenant_mp.id)
      expect(suscripcion).not_to be_valid
      expect(suscripcion.errors[:tenant_id]).to be_present
    end

    it "no persiste un Pago cuyo tenant_id no es el de su membresía" do
      membresia = membresias(:activa_one)
      pago = membresia.pagos.new(monto: 80_000, metodo: "efectivo",
                                 registrado_por: users(:admin), fecha_pago: Date.current,
                                 periodo_inicio: Date.current, periodo_fin: Date.current + 30,
                                 tenant_id: tenant_mp.id)
      expect(pago).not_to be_valid
      expect(pago.errors[:tenant_id]).to be_present
    end
  end

  # El modo de falla correcto de un control de seguridad: una fila sin tenant
  # (legado que el backfill no alcanzó) queda INVISIBLE para el staff, no
  # visible para todos.
  describe "fail-closed de los Scopes" do
    it "el staff no ve una membresía con tenant_id nulo" do
      membresia = membresias(:activa_one)
      membresia.update_column(:tenant_id, nil)

      alcance = MembresiaPolicy::Scope.new(users(:admin), Membresia).resolve
      expect(alcance).not_to include(membresia)
    end

    it "un staff sin tenant (rol global) no ve ninguna membresía" do
      superadmin = User.create!(email_address: "sa-scope@x.com", password: "clave1234",
                                rol: "superadmin", nombre: "SA")
      alcance = MembresiaPolicy::Scope.new(superadmin, Membresia).resolve
      expect(alcance).to be_empty
    end
  end
end
