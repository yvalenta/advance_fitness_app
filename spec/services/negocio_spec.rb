require "rails_helper"

RSpec.describe Negocio, type: :model do
  it "lee los valores por defecto de config/negocio.yml" do
    expect(Negocio.precio_mensualidad).to eq(80_000)
    expect(Negocio.precio_personalizado).to eq(350_000)
    expect(Negocio.duracion_dias).to eq(30)
    expect(Negocio.nombre.present?).to be_truthy
  end

  it "una variable de entorno sobreescribe la config" do
    original = ENV["PRECIO_MENSUALIDAD"]
    ENV["PRECIO_MENSUALIDAD"] = "120000"
    expect(Negocio.precio_mensualidad).to eq(120_000)
  ensure
    original.nil? ? ENV.delete("PRECIO_MENSUALIDAD") : ENV["PRECIO_MENSUALIDAD"] = original
  end
end
