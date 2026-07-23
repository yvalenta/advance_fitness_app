require "rails_helper"

RSpec.describe Negocio, type: :model do
  it "lee los valores por defecto de config/negocio.yml" do
    expect(Negocio.precio_mensualidad).to eq(80_000)
    expect(Negocio.precio_personalizado).to eq(350_000)
    expect(Negocio.duracion_dias).to eq(30)
    expect(Negocio.nombre.present?).to be_truthy
    expect(Negocio.ciudad.present?).to be_truthy
  end

  it "una variable de entorno sobreescribe la config" do
    original = ENV["PRECIO_MENSUALIDAD"]
    ENV["PRECIO_MENSUALIDAD"] = "120000"
    expect(Negocio.precio_mensualidad).to eq(120_000)
  ensure
    original.nil? ? ENV.delete("PRECIO_MENSUALIDAD") : ENV["PRECIO_MENSUALIDAD"] = original
  end

  # Multi-tenant (SDD §16.6): los valores del tenant tienen prioridad sobre
  # ENV y YAML global. Sin tenant se cae al comportamiento single-tenant.
  context "con Current.tenant" do
    after { Current.reset }

    it "prioriza los precios/nombre del tenant" do
      tenant = tenants(:megaplex)
      tenant.update!(precio_personalizado: 999_000, precio_mensualidad: 55_000, duracion_dias: 45)
      Current.tenant = tenant

      expect(Negocio.precio_personalizado).to eq(999_000)
      expect(Negocio.precio_mensualidad).to eq(55_000)
      expect(Negocio.duracion_dias).to eq(45)
      expect(Negocio.nombre).to eq("Megaplex")
    end

    it "cae al default global cuando el tenant no fija los precios" do
      Current.tenant = tenants(:advance_fitness)
      expect(Negocio.precio_personalizado).to eq(350_000)
      expect(Negocio.duracion_dias).to eq(30)
    end

    describe ".theme_color" do
      it "default cuando no hay tenant" do
        expect(Negocio.theme_color).to eq(Negocio::DEFAULT_THEME_COLOR)
      end

      it "usa el primary del tenant cuando es hex válido" do
        tenant = tenants(:megaplex)
        tenant.update!(paleta_colores: { "primary" => "#ff8800" })
        Current.tenant = tenant

        expect(Negocio.theme_color).to eq("#ff8800")
      end

      it "ignora valores no-hex (defensa contra CSS injection)" do
        tenant = tenants(:megaplex)
        tenant.update!(paleta_colores: { "primary" => "red; }body{display:none}" })
        Current.tenant = tenant

        expect(Negocio.theme_color).to eq(Negocio::DEFAULT_THEME_COLOR)
      end
    end
  end
end
