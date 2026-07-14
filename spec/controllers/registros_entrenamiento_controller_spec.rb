require "rails_helper"

RSpec.describe "RegistrosEntrenamiento", type: :request do
  it "el miembro marca un ejercicio del día (upsert por fecha)" do
    sign_in_as users(:one)

    expect {
      post registros_entrenamiento_path, as: :json, params: {
        fecha: Date.current.iso8601, indice: 0, hecho: true, nota: "subí peso", nombre: "Press banca"
      }
    }.to change(RegistroEntrenamiento, :count).by(1)
    expect(response).to have_http_status(:success)

    registro = users(:one).registros_entrenamiento.find_by(fecha: Date.current)
    expect(registro.estado_de(0)["hecho"]).to eq(true)
    expect(registro.estado_de(0)["nota"]).to eq("subí peso")
  end

  it "marcar el mismo día otro ejercicio no duplica la fila" do
    sign_in_as users(:one)
    users(:one).registros_entrenamiento.create!(fecha: Date.current)

    expect {
      post registros_entrenamiento_path, as: :json, params: {
        fecha: Date.current.iso8601, indice: 1, hecho: true, nombre: "Fondos"
      }
    }.not_to change(RegistroEntrenamiento, :count)
  end

  it "puede marcar un día pasado" do
    sign_in_as users(:one)
    ayer = Date.yesterday

    post registros_entrenamiento_path, as: :json,
         params: { fecha: ayer.iso8601, indice: 0, hecho: true, nombre: "Remo" }

    expect(users(:one).registros_entrenamiento.find_by(fecha: ayer).estado_de(0)["hecho"]).to be_truthy
  end

  # Fase 5.11: novedad para toda la rutina del día
  it "guarda la novedad del día sin tocar los checks" do
    sign_in_as users(:one)
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    registro.marcar!(0, hecho: true, nombre: "Press banca")

    post registros_entrenamiento_path, as: :json,
         params: { fecha: Date.current.iso8601, novedad: "entrené en otra sede" }

    expect(response).to have_http_status(:success)
    expect(registro.reload.novedad).to eq("entrené en otra sede")
    expect(registro.estado_de(0)["hecho"]).to eq(true)
  end

  it "marcar sin nota conserva la nota previa" do
    sign_in_as users(:one)
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    registro.marcar!(0, hecho: true, nota: "con mancuernas", nombre: "Press")

    post registros_entrenamiento_path, as: :json,
         params: { fecha: Date.current.iso8601, indice: 0, hecho: false, nombre: "Press" }

    estado = registro.reload.estado_de(0)
    expect(estado["hecho"]).to eq(false)
    expect(estado["nota"]).to eq("con mancuernas")
  end

  it "sin sesión no registra" do
    expect {
      post registros_entrenamiento_path, as: :json, params: { fecha: Date.current.iso8601, indice: 0, hecho: true }
    }.not_to change(RegistroEntrenamiento, :count)
    expect(response).to have_http_status(:redirect)
  end
end
