require "rails_helper"

RSpec.describe Logro, type: :model do
  def crear_logro(codigo: "primera-sesion", tenant: nil)
    Logro.create!(codigo: codigo, nombre: "Primera sesión", puntos: 20,
                  categoria: "constancia", tenant: tenant)
  end

  it "valida codigo único, nombre, puntos y categoría" do
    crear_logro
    expect(Logro.new(codigo: "primera-sesion", nombre: "Duplicado",
                     puntos: 5, categoria: "constancia")).not_to be_valid
    expect(Logro.new(codigo: "x", nombre: "", puntos: 5, categoria: "constancia")).not_to be_valid
    expect(Logro.new(codigo: "x", nombre: "X", puntos: -1, categoria: "constancia")).not_to be_valid
    expect(Logro.new(codigo: "x", nombre: "X", puntos: 5, categoria: "rara")).not_to be_valid
  end

  it "tenant nil = catálogo global; con tenant = del gimnasio" do
    global = crear_logro
    propio = crear_logro(codigo: "racha-7", tenant: tenants(:advance_fitness))
    expect(global.global?).to be true
    expect(propio.global?).to be false
  end
end

RSpec.describe LogroObtenido, type: :model do
  let(:user) { users(:one) }
  let(:logro) do
    Logro.create!(codigo: "primera-sesion", nombre: "Primera sesión",
                  puntos: 20, categoria: "constancia")
  end

  it "exige obtenido_en y es único por (user, logro): un logro se gana una vez" do
    expect(LogroObtenido.new(user: user, logro: logro)).not_to be_valid

    LogroObtenido.create!(user: user, logro: logro, obtenido_en: Time.current)
    repetido = LogroObtenido.new(user: user, logro: logro, obtenido_en: Time.current)
    expect(repetido).not_to be_valid

    # Y aunque la validación se salte, la base lo rechaza:
    expect {
      repetido.save!(validate: false)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
