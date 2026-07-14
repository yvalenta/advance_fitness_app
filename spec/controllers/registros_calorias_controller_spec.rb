require "rails_helper"

RSpec.describe "RegistrosCalorias", type: :request do
  it "el miembro registra su consumo con detalle por comida" do
    sign_in_as users(:one)
    detalle = { comidas: [ { nombre: "Desayuno", kcal: 300, nota: "quinoa" } ] }.to_json

    post registros_calorias_path, params: { registro_caloria: { kcal_consumidas: 300, detalle: detalle } }

    registro = users(:one).registros_calorias.find_by(fecha: Date.current)
    expect(registro.kcal_consumidas).to eq(300)
    expect(registro.detalle.dig("comidas", 0, "nota")).to eq("quinoa")
  end

  it "un detalle con JSON roto no rompe el registro del día" do
    sign_in_as users(:one)
    post registros_calorias_path, params: { registro_caloria: { kcal_consumidas: 200, detalle: "{roto" } }

    registro = users(:one).registros_calorias.find_by(fecha: Date.current)
    expect(registro.kcal_consumidas).to eq(200)
    expect(registro.detalle).to eq({})
  end

  # Fase 5.11: el historial es editable por fecha
  it "corrige las kcal de un día pasado sin duplicar" do
    RegistroCaloria.registrar(users(:one), kcal: 1500, fecha: Date.yesterday)
    sign_in_as users(:one)

    expect {
      post registros_calorias_path,
           params: { registro_caloria: { kcal_consumidas: 1800, fecha: Date.yesterday.iso8601 } }
    }.not_to change(RegistroCaloria, :count)
    expect(users(:one).registros_calorias.find_by(fecha: Date.yesterday).kcal_consumidas).to eq(1800)
  end

  it "no permite registrar un día futuro" do
    sign_in_as users(:one)

    expect {
      post registros_calorias_path,
           params: { registro_caloria: { kcal_consumidas: 1800, fecha: Date.tomorrow.iso8601 } }
    }.not_to change(RegistroCaloria, :count)
    expect(response).to redirect_to(objetivo_path)
  end
end
