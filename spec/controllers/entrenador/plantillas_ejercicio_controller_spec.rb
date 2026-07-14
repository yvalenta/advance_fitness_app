require "rails_helper"

RSpec.describe "Entrenador::PlantillasEjercicio", type: :request do
  params = { plantilla_ejercicio: { musculo: "espalda", nombre: "Remo en punta",
                                    series: 4, repeticiones: "8-10", descanso_seg: 90 } }.freeze

  it "el entrenador guarda una plantilla desde el editor" do
    sign_in_as users(:entrenador)

    expect {
      post entrenador_plantillas_ejercicio_path, params: params, as: :json
    }.to change(PlantillaEjercicio, :count).by(1)
    expect(response).to have_http_status(:created)
    expect(PlantillaEjercicio.last.creado_por).to eq(users(:entrenador))
  end

  it "un miembro no puede crear ni borrar plantillas de ejercicio" do
    sign_in_as users(:one)

    expect {
      post entrenador_plantillas_ejercicio_path, params: params, as: :json
      delete entrenador_plantilla_ejercicio_path(plantillas_ejercicio(:sentadilla))
    }.not_to change(PlantillaEjercicio, :count)
  end

  it "el staff puede retirar una plantilla" do
    sign_in_as users(:admin)

    expect {
      delete entrenador_plantilla_ejercicio_path(plantillas_ejercicio(:sentadilla))
    }.to change(PlantillaEjercicio, :count).by(-1)
  end
end
