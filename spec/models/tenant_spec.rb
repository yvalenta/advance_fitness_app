require "rails_helper"

RSpec.describe Tenant, type: :model do
  it "exige nombre, slug, tipo y email" do
    expect(Tenant.new.valid?).to be_falsey
  end

  it "normaliza el slug a minúsculas/guiones" do
    tenant = Tenant.create!(nombre: "Nuevo", slug: "Nuevo Gym!!", tipo_entidad: "gimnasio",
                            email_contacto: "n@x.com")
    expect(tenant.slug).to eq("nuevo-gym")
  end

  it "rechaza slugs reservados" do
    tenant = Tenant.new(nombre: "X", slug: "comercial", tipo_entidad: "gimnasio",
                        email_contacto: "n@x.com")
    expect(tenant.valid?).to be_falsey
    expect(tenant.errors[:slug]).to be_present
  end

  it "el tipo debe ser gimnasio/entrenador/influencer" do
    tenant = Tenant.new(nombre: "X", slug: "x", tipo_entidad: "otro", email_contacto: "n@x.com")
    expect(tenant.valid?).to be_falsey
  end

  it "membresias_habilitadas? default sigue al tipo cuando no está en el jsonb" do
    entrenador = Tenant.new(features_habilitadas: {}, tipo_entidad: "entrenador")
    gimnasio = Tenant.new(features_habilitadas: {}, tipo_entidad: "gimnasio")
    expect(entrenador.membresias_habilitadas?).to be false
    expect(gimnasio.membresias_habilitadas?).to be true
  end

  it "membresias_habilitadas? respeta el override explícito del jsonb" do
    influencer_on = Tenant.new(features_habilitadas: { "membresias" => true }, tipo_entidad: "influencer")
    gimnasio_off = Tenant.new(features_habilitadas: { "membresias" => false }, tipo_entidad: "gimnasio")
    expect(influencer_on.membresias_habilitadas?).to be true
    expect(gimnasio_off.membresias_habilitadas?).to be false
  end
end
