require "rails_helper"

RSpec.describe "Entrenador::PlantillasComida", type: :request do
  params = { plantilla_comida: { tipo: "almuerzo", nombre: "Bowl de pollo · 600 kcal",
                                 descripcion: "Pollo con arroz y aguacate.", kcal: 600,
                                 proteinas_g: 45, carbohidratos_g: 70, grasas_g: 18 } }.freeze

  it "el entrenador guarda una plantilla desde el editor" do
    sign_in_as users(:entrenador)

    expect {
      post entrenador_plantillas_comida_path, params: params, as: :json
    }.to change(PlantillaComida, :count).by(1)

    expect(response).to have_http_status(:created)
    plantilla = PlantillaComida.last
    expect(plantilla.nombre).to eq("Bowl de pollo · 600 kcal")
    expect(plantilla.creado_por).to eq(users(:entrenador))
    expect(response.parsed_body["tipo"]).to eq("almuerzo")
  end

  it "una plantilla duplicada devuelve el error" do
    sign_in_as users(:entrenador)
    existente = plantillas_comida(:desayuno_avena)

    post entrenador_plantillas_comida_path, as: :json,
         params: { plantilla_comida: existente.attributes.slice(
           "tipo", "nombre", "descripcion", "kcal", "proteinas_g", "carbohidratos_g", "grasas_g"
         ) }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["errores"].any?).to be_truthy
  end

  it "un miembro no puede crear ni borrar plantillas" do
    sign_in_as users(:one)

    expect {
      post entrenador_plantillas_comida_path, params: params, as: :json
      delete entrenador_plantilla_comida_path(plantillas_comida(:cena_ligera))
    }.not_to change(PlantillaComida, :count)
  end

  it "el staff puede retirar una plantilla" do
    sign_in_as users(:admin)

    expect {
      delete entrenador_plantilla_comida_path(plantillas_comida(:cena_ligera))
    }.to change(PlantillaComida, :count).by(-1)
  end
end
