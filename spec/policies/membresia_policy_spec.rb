require "rails_helper"

RSpec.describe MembresiaPolicy, type: :model do
  before do
    @membresia = membresias(:activa_one)
    @dueno = users(:one)
    @otro = users(:two)
    @entrenador = users(:entrenador)
    @admin = users(:admin)
    @recepcion = users(:recepcion)
  end

  it "el miembro ve su membresía pero no la de otro" do
    expect(MembresiaPolicy.new(@dueno, @membresia).show?).to be_truthy
    expect(MembresiaPolicy.new(@otro, @membresia).show?).to be_falsey
  end

  it "staff y mostrador crean y editan; el miembro no" do
    expect(MembresiaPolicy.new(@dueno, @membresia).create?).to be_falsey
    expect(MembresiaPolicy.new(@entrenador, @membresia).create?).to be_truthy
    expect(MembresiaPolicy.new(@admin, @membresia).update?).to be_truthy
  end

  it "recepción crea, ve y edita membresías (alta de mostrador)" do
    expect(MembresiaPolicy.new(@recepcion, @membresia).index?).to be_truthy
    expect(MembresiaPolicy.new(@recepcion, @membresia).show?).to be_truthy
    expect(MembresiaPolicy.new(@recepcion, @membresia).create?).to be_truthy
    expect(MembresiaPolicy.new(@recepcion, @membresia).update?).to be_truthy
  end

  it "renueva quien cobra: admin y recepción, no el entrenador" do
    expect(MembresiaPolicy.new(@entrenador, @membresia).renovar?).to be_falsey
    expect(MembresiaPolicy.new(@admin, @membresia).renovar?).to be_truthy
    expect(MembresiaPolicy.new(@recepcion, @membresia).renovar?).to be_truthy
  end

  it "nadie elimina membresías, tampoco recepción" do
    expect(MembresiaPolicy.new(@admin, @membresia).destroy?).to be_falsey
    expect(MembresiaPolicy.new(@recepcion, @membresia).destroy?).to be_falsey
  end

  it "scope: miembro solo la propia, staff y mostrador todas las del tenant" do
    expect(MembresiaPolicy::Scope.new(@dueno, Membresia).resolve.to_a).to eq([ @membresia ])
    expect(MembresiaPolicy::Scope.new(@admin, Membresia).resolve.count).to eq(Membresia.count)
    expect(MembresiaPolicy::Scope.new(@recepcion, Membresia).resolve.count).to eq(Membresia.count)
  end

  # Defensa en profundidad (tarea 2026-08-31): además del rol, la fila ancla
  # por tenant_id (persistida) o por el tenant estacionado del dueño (nueva).
  it "el admin de A no ve, edita, renueva ni da de alta plata anclada en B" do
    miembro_mp = User.create!(email_address: "miembro-mp@x.com", password: "clave1234",
                              rol: "miembro", tenant: tenants(:megaplex), nombre: "Miembro MP")
    membresia_mp = Membresia.create!(user: miembro_mp, estado: "activa",
                                     fecha_inicio: Date.current,
                                     fecha_vencimiento: Date.current + 30)

    expect(MembresiaPolicy.new(@admin, membresia_mp).show?).to be_falsey
    expect(MembresiaPolicy.new(@admin, membresia_mp).update?).to be_falsey
    expect(MembresiaPolicy.new(@admin, membresia_mp).renovar?).to be_falsey
    # Alta nueva apuntando a un dueño de B: también negada.
    expect(MembresiaPolicy.new(@admin, Membresia.new(user: miembro_mp)).create?).to be_falsey
    # …y el dueño de B sigue viendo la suya.
    expect(MembresiaPolicy.new(miembro_mp, membresia_mp).show?).to be_truthy
  end
end
