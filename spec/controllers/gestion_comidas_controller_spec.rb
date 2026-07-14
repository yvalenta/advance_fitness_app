require "rails_helper"

RSpec.describe "GestionComidas", type: :request do
  rutina = { "dias" => [] }.freeze
  nutricion = { "kcal_diarias" => 900, "comidas" => [
    { "nombre" => "Desayuno", "descripcion" => "Huevos", "kcal" => 400,
      "proteinas_g" => 30, "carbohidratos_g" => 40, "grasas_g" => 15 },
    { "nombre" => "Cena", "descripcion" => "Salmón", "kcal" => 500,
      "proteinas_g" => 35, "carbohidratos_g" => 40, "grasas_g" => 22 }
  ] }.freeze

  before do
    @plan = PlanPersonalizado.create!(user: users(:one), rutina: rutina, plan_nutricional: nutricion)
  end

  it "el staff autosalva una comida por índice y recibe el total recalculado" do
    sign_in_as users(:entrenador)

    patch plan_personalizado_comida_path(@plan, 0), as: :json,
          params: { comida: { nombre: "Desayuno power", descripcion: "Avena", kcal: "520",
                              proteinas_g: "35", carbohidratos_g: "60", grasas_g: "12" } }

    expect(response).to have_http_status(:success)
    expect(response.parsed_body["kcal_diarias"]).to eq(1020) # 520 + 500
    expect(@plan.reload.comidas.first["nombre"]).to eq("Desayuno power")
  end

  it "agregar y eliminar comidas responde turbo_stream sin recargar" do
    sign_in_as users(:admin)

    expect {
      post plan_personalizado_comidas_path(@plan),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }, params: { comida: { nombre: "Snack", kcal: "150" } }
    }.to change { @plan.reload.comidas.size }.by(1)
    expect(response).to have_http_status(:success)
    expect(response.media_type).to match("turbo-stream")
    assert_select "turbo-stream[action=replace][target=editor_nutricional]"

    expect {
      delete plan_personalizado_comida_path(@plan, 0), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    }.to change { @plan.reload.comidas.size }.by(-1)
    expect(response).to have_http_status(:success)
  end

  it "un índice inexistente responde 404 sin romper" do
    sign_in_as users(:entrenador)
    patch plan_personalizado_comida_path(@plan, 99), as: :json, params: { comida: { kcal: "100" } }
    expect(response).to have_http_status(:not_found)
  end

  it "un miembro no puede editar las comidas de un plan" do
    sign_in_as users(:one)

    expect {
      patch plan_personalizado_comida_path(@plan, 0), as: :json, params: { comida: { kcal: "999" } }
    }.not_to change { @plan.reload.comidas.first["kcal"] }
    expect(response).to have_http_status(:redirect)
  end

  # Fase 5.12: el miembro edita la rutina de su plan de IA una vez publicado,
  # pero la NUTRICIÓN de un plan de IA sigue siendo exclusiva del staff.
  it "ni publicado el miembro edita la nutrición de su plan de IA" do
    publicado = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "aprobado",
                                          aprobado_por: users(:entrenador), rutina: rutina, plan_nutricional: nutricion)
    sign_in_as users(:one)

    expect {
      patch plan_personalizado_comida_path(publicado, 0), as: :json, params: { comida: { kcal: "999" } }
    }.not_to change { publicado.reload.comidas.first["kcal"] }
    expect(response).to have_http_status(:redirect)
  end
end
