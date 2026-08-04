require "rails_helper"

RSpec.describe PerfilJuego, type: :model do
  let(:user) { users(:one) }

  it "hereda el tenant del user (TenantDesnormalizado) sin que nadie lo pase" do
    perfil = PerfilJuego.create!(user: user)
    expect(perfil.tenant_id).to eq user.tenant_id
  end

  it "rechaza un tenant_id incoherente con el del user (mass-assignment)" do
    otro_tenant = tenants(:megaplex)
    perfil = PerfilJuego.new(user: user, tenant_id: otro_tenant.id)
    expect(perfil).not_to be_valid
    expect(perfil.errors[:tenant_id]).to be_present
  end

  it "un perfil por user (validación + índice único)" do
    PerfilJuego.create!(user: user)
    expect(PerfilJuego.new(user: user)).not_to be_valid
  end

  it "arranca en cero: nivel 1, sin puntos, sin racha, oculto de la tabla" do
    perfil = PerfilJuego.create!(user: user)
    expect(perfil.puntos_total).to eq 0
    expect(perfil.nivel).to eq 1
    expect(perfil.racha_actual).to eq 0
    expect(perfil.visible_en_tabla).to be false
  end

  it "nivel_para: cuadrática documentada — 0-99 → 1, 100 → 2, 400 → 3, 900 → 4" do
    expect(PerfilJuego.nivel_para(0)).to eq 1
    expect(PerfilJuego.nivel_para(99)).to eq 1
    expect(PerfilJuego.nivel_para(100)).to eq 2
    expect(PerfilJuego.nivel_para(399)).to eq 2
    expect(PerfilJuego.nivel_para(400)).to eq 3
    expect(PerfilJuego.nivel_para(900)).to eq 4
    expect(PerfilJuego.nivel_para(-50)).to eq 1 # ajustes manuales en rojo no rompen
  end

  it "PerfilJuego.para es find-or-create idempotente" do
    a = PerfilJuego.para(user)
    b = PerfilJuego.para(user)
    expect(a.id).to eq b.id
    expect(PerfilJuego.where(user: user).count).to eq 1
  end
end
