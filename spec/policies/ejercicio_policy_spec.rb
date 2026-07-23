require "rails_helper"

# El catálogo de ejercicios es global (SDD §16.6) — todo usuario autenticado
# consulta el mismo catálogo. No hay aislamiento por tenant a propósito.
RSpec.describe EjercicioPolicy, type: :model do
  let(:miembro) { users(:one) }

  it "usuarios autenticados pueden consultar el catálogo" do
    policy = EjercicioPolicy.new(miembro, Ejercicio)
    expect(policy.index?).to be true
    expect(policy.ayuda?).to be true
    expect(policy.media?).to be true
  end

  it "sin usuario, todo negado" do
    policy = EjercicioPolicy.new(nil, Ejercicio)
    expect(policy.index?).to be_falsey
    expect(policy.ayuda?).to be_falsey
    expect(policy.media?).to be_falsey
  end
end
