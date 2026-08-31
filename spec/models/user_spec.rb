require "rails_helper"

RSpec.describe User, type: :model do
  it "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    expect(user.email_address).to eq("downcased@example.com")
  end

  it "VIP siempre cuenta como premium, sin importar la suscripción (Fase 12.2)" do
    expect(users(:one).premium?).to be_falsey
    users(:one).update!(vip: true)
    expect(users(:one).premium?).to be_truthy
  end

  it "requiere tenant para miembro/entrenador/admin (SDD §16.6)" do
    user = User.new(email_address: "sin@tenant.com", password: "clave1234", rol: "miembro")
    expect(user.valid?).to be_falsey
    expect(user.errors[:tenant]).to be_present
  end

  it "no requiere tenant para superadmin ni comercializador" do
    %w[superadmin comercializador].each do |rol|
      user = User.new(email_address: "#{rol}@x.com", password: "clave1234", rol: rol)
      expect(user.valid?).to be_truthy, "#{rol} debería ser válido sin tenant: #{user.errors.full_messages}"
    end
  end

  it "helpers de rol global" do
    expect(User.new(rol: "superadmin").superadmin?).to be true
    expect(User.new(rol: "comercializador").comercializador?).to be true
    expect(User.new(rol: "superadmin").global?).to be true
    expect(User.new(rol: "miembro").global?).to be false
  end

  # El embudo del cambio de organización (tarea 2026-08-31): la ÚNICA
  # dirección puesto → cache.
  describe "#estacionar_en!" do
    let(:megaplex) { tenants(:megaplex) }

    it "sin puesto en el tenant destino levanta y NO toca la cache" do
      user = users(:one) # puesto solo en advance_fitness

      expect { user.estacionar_en!(megaplex) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(user.reload.tenant_id).to eq(tenants(:advance_fitness).id)
      expect(user.rol).to eq("miembro")
    end

    it "con puesto sincroniza tenant_id y rol de la cache copiando DEL puesto" do
      user = users(:one)
      user.puestos.create!(tenant: megaplex, rol: "entrenador")

      user.estacionar_en!(megaplex)

      expect(user.reload.tenant_id).to eq(megaplex.id)
      expect(user.rol).to eq("entrenador") # el rol de ALLÁ, no el que traía
    end
  end

  # El espejo cache → puestos (after_save): garantiza que toda cuenta creada
  # o movida por los flujos legados (registro, alta del mostrador, admin
  # inicial de un tenant nuevo, seeds) nazca con el puesto que
  # `verificar_pertenencia_al_tenant` va a exigir.
  describe "sincronización del puesto con la cache" do
    it "al crear un user con tenant nace su puesto espejo con el mismo rol" do
      user = User.create!(email_address: "nueva@x.com", password: "clave1234",
                          rol: "recepcion", tenant: tenants(:megaplex), nombre: "Nueva")

      expect(user.puestos.pluck(:tenant_id, :rol)).to eq([ [ tenants(:megaplex).id, "recepcion" ] ])
    end

    it "al cambiar el rol de la cache se sincroniza el puesto del par estacionado" do
      users(:one).update!(rol: "entrenador")

      expect(puestos(:one).reload.rol).to eq("entrenador")
    end

    it "los roles globales jamás generan puesto" do
      sa = User.create!(email_address: "sa2@x.com", password: "clave1234",
                        rol: "superadmin", nombre: "SA")

      expect(sa.puestos).to be_empty
    end
  end
end
