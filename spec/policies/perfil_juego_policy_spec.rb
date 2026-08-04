require "rails_helper"

RSpec.describe PerfilJuegoPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:admin) { users(:admin) }
  let(:perfil_propio) { PerfilJuego.create!(user: dueno) }
  let(:perfil_ajeno) { PerfilJuego.create!(user: otro) }

  it "index? para todos (el leaderboard es de los miembros)" do
    expect(PerfilJuegoPolicy.new(dueno, PerfilJuego).index?).to be true
    expect(PerfilJuegoPolicy.new(admin, PerfilJuego).index?).to be true
  end

  it "show?: dueño o staff" do
    expect(PerfilJuegoPolicy.new(dueno, perfil_propio).show?).to be true
    expect(PerfilJuegoPolicy.new(otro, perfil_propio).show?).to be false
    expect(PerfilJuegoPolicy.new(admin, perfil_propio).show?).to be true
  end

  it "update?: SOLO el propio miembro — el staff jamás activa visible_en_tabla por él" do
    expect(PerfilJuegoPolicy.new(dueno, perfil_propio).update?).to be true
    expect(PerfilJuegoPolicy.new(otro, perfil_propio).update?).to be false
    expect(PerfilJuegoPolicy.new(admin, perfil_propio).update?).to be false
  end

  it "create?/destroy? nadie: los perfiles los administra el motor" do
    expect(PerfilJuegoPolicy.new(admin, perfil_propio).create?).to be false
    expect(PerfilJuegoPolicy.new(admin, perfil_propio).destroy?).to be false
  end

  it "Scope: filtra por tenant_id directo para todos los roles" do
    perfil_propio; perfil_ajeno
    expect(PerfilJuegoPolicy::Scope.new(dueno, PerfilJuego).resolve)
      .to contain_exactly(perfil_propio, perfil_ajeno)
    expect(PerfilJuegoPolicy::Scope.new(admin, PerfilJuego).resolve)
      .to contain_exactly(perfil_propio, perfil_ajeno)
  end
end
