require "rails_helper"

RSpec.describe MembresiaPolicy, type: :model do
  before do
    @membresia = membresias(:activa_one)
    @dueno = users(:one)
    @otro = users(:two)
    @entrenador = users(:entrenador)
    @admin = users(:admin)
  end

  it "el miembro ve su membresía pero no la de otro" do
    expect(MembresiaPolicy.new(@dueno, @membresia).show?).to be_truthy
    expect(MembresiaPolicy.new(@otro, @membresia).show?).to be_falsey
  end

  it "solo staff crea y edita" do
    expect(MembresiaPolicy.new(@dueno, @membresia).create?).to be_falsey
    expect(MembresiaPolicy.new(@entrenador, @membresia).create?).to be_truthy
    expect(MembresiaPolicy.new(@admin, @membresia).update?).to be_truthy
  end

  it "solo admin renueva (registra pagos)" do
    expect(MembresiaPolicy.new(@entrenador, @membresia).renovar?).to be_falsey
    expect(MembresiaPolicy.new(@admin, @membresia).renovar?).to be_truthy
  end

  it "nadie elimina membresías" do
    expect(MembresiaPolicy.new(@admin, @membresia).destroy?).to be_falsey
  end

  it "scope: miembro solo la propia, staff todas" do
    expect(MembresiaPolicy::Scope.new(@dueno, Membresia).resolve.to_a).to eq([ @membresia ])
    expect(MembresiaPolicy::Scope.new(@admin, Membresia).resolve.count).to eq(Membresia.count)
  end
end
