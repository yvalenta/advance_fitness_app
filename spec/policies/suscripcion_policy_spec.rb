require "rails_helper"

RSpec.describe SuscripcionPolicy, type: :model do
  let(:susc) do
    Suscripcion.create!(user: users(:one), plan: planes(:free), estado: "activa",
                        fecha_inicio: Date.current)
  end

  it "index?/create?/update?: solo admin (SDD §08 flujo B)" do
    expect(SuscripcionPolicy.new(users(:one), susc).index?).to be false
    expect(SuscripcionPolicy.new(users(:entrenador), susc).create?).to be false
    expect(SuscripcionPolicy.new(users(:admin), susc).index?).to be true
    expect(SuscripcionPolicy.new(users(:admin), susc).create?).to be true
    expect(SuscripcionPolicy.new(users(:admin), susc).update?).to be true
  end

  # Defensa en profundidad (tarea 2026-08-31): update? además ancla la fila
  # por su tenant_id — el admin de A no cancela ni cambia el tier en B.
  it "update?: el admin de A no toca una suscripción anclada en B" do
    miembro_mp = User.create!(email_address: "miembro-mp@x.com", password: "clave1234",
                              rol: "miembro", tenant: tenants(:megaplex), nombre: "Miembro MP")
    susc_mp = Suscripcion.create!(user: miembro_mp, plan: planes(:free), estado: "activa",
                                  fecha_inicio: Date.current)

    expect(susc_mp.tenant_id).to eq(tenants(:megaplex).id) # heredado del dueño
    expect(SuscripcionPolicy.new(users(:admin), susc_mp).update?).to be false
  end
end
