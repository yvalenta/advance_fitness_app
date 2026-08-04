require "rails_helper"

RSpec.describe "RegistrosEntrenamiento", type: :request do
  # Fase 14.6: ajustado a la firma nueva de estado_de (keywords). El POST sin
  # uid es el caso de un plan previo al uid: el ancla sigue siendo posicional.
  it "el miembro marca un ejercicio del día (upsert por fecha)" do
    sign_in_as users(:one)

    expect {
      post registros_entrenamiento_path, as: :json, params: {
        fecha: Date.current.iso8601, indice: 0, hecho: true, nota: "subí peso", nombre: "Press banca"
      }
    }.to change(RegistroEntrenamiento, :count).by(1)
    expect(response).to have_http_status(:success)

    registro = users(:one).registros_entrenamiento.find_by(fecha: Date.current)
    expect(registro.estado_de(indice: 0)["hecho"]).to eq(true)
    expect(registro.estado_de(indice: 0)["nota"]).to eq("subí peso")
  end

  # Fase 14.6: el flujo nuevo — el Stimulus manda el uid estable del ejercicio
  # y el registro nace v2 con el plan aprobado y el metadato histórico.
  it "marca por uid y escribe v2 con plan_id y dia/indice como metadato" do
    sign_in_as users(:one)
    plan = PlanPersonalizado.create!(user: users(:one), estado: "aprobado",
                                     aprobado_por: users(:entrenador),
                                     rutina: { "dias" => [ { "dia" => "lunes", "ejercicios" => [] } ] },
                                     plan_nutricional: { "comidas" => [] })

    post registros_entrenamiento_path, as: :json, params: {
      fecha: Date.current.iso8601, uid: "uidpress01", indice: 2, hecho: true, nombre: "Press banca"
    }
    expect(response).to have_http_status(:success)

    datos = users(:one).registros_entrenamiento.find_by(fecha: Date.current).ejercicios
    expect(datos["version"]).to eq(2)
    expect(datos["plan_id"]).to eq(plan.id)
    expect(datos.dig("items", "uidpress01")).to include(
      "hecho" => true, "nombre" => "Press banca", "indice" => 2,
      "dia" => (Date.current.wday - 1) % 7
    )
  end

  it "marcar el mismo día otro ejercicio no duplica la fila" do
    sign_in_as users(:one)
    users(:one).registros_entrenamiento.create!(fecha: Date.current)

    expect {
      post registros_entrenamiento_path, as: :json, params: {
        fecha: Date.current.iso8601, uid: "uidfondos1", indice: 1, hecho: true, nombre: "Fondos"
      }
    }.not_to change(RegistroEntrenamiento, :count)
  end

  # Fase 14.6: ajustado a la firma nueva de estado_de (keywords).
  it "puede marcar un día pasado" do
    sign_in_as users(:one)
    ayer = Date.yesterday

    post registros_entrenamiento_path, as: :json,
         params: { fecha: ayer.iso8601, uid: "uidremo001", indice: 0, hecho: true, nombre: "Remo" }

    expect(users(:one).registros_entrenamiento.find_by(fecha: ayer).estado_de(uid: "uidremo001")["hecho"]).to be_truthy
  end

  # Fase 5.11: novedad para toda la rutina del día
  # Fase 14.6: ajustado a la firma nueva de marcar!/estado_de.
  it "guarda la novedad del día sin tocar los checks" do
    sign_in_as users(:one)
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    registro.marcar!(uid: "uidpress01", hecho: true, nombre: "Press banca", dia: 0, indice: 0)

    post registros_entrenamiento_path, as: :json,
         params: { fecha: Date.current.iso8601, novedad: "entrené en otra sede" }

    expect(response).to have_http_status(:success)
    expect(registro.reload.novedad).to eq("entrené en otra sede")
    expect(registro.estado_de(uid: "uidpress01")["hecho"]).to eq(true)
  end

  # Fase 14.6: ajustado a la firma nueva de marcar!/estado_de; el re-marcado
  # llega con el mismo uid, como lo manda el Stimulus.
  it "marcar sin nota conserva la nota previa" do
    sign_in_as users(:one)
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    registro.marcar!(uid: "uidpress01", hecho: true, nota: "con mancuernas", nombre: "Press", dia: 0, indice: 0)

    post registros_entrenamiento_path, as: :json,
         params: { fecha: Date.current.iso8601, uid: "uidpress01", indice: 0, hecho: false, nombre: "Press" }

    estado = registro.reload.estado_de(uid: "uidpress01")
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
