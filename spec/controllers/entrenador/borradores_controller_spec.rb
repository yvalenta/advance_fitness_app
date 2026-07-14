require "rails_helper"

RSpec.describe "Entrenador::Borradores", type: :request do
  rutina = { "dias" => [ { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [] } ] }.freeze
  nutricion = { "kcal_diarias" => 450, "comidas" => [ { "nombre" => "Desayuno", "descripcion" => "Huevos con arepa",
                 "kcal" => 450, "proteinas_g" => 30, "carbohidratos_g" => 40, "grasas_g" => 15 } ] }.freeze

  before do
    @plan = PlanPersonalizado.create!(user: users(:one), rutina: rutina, plan_nutricional: nutricion)
  end

  it "un miembro no accede a la cola de borradores" do
    sign_in_as users(:one)
    get entrenador_borradores_path
    expect(response).to redirect_to(root_path)
  end

  it "el entrenador ve la cola de revisión con enlace al editor" do
    sign_in_as users(:entrenador)
    get entrenador_borradores_path

    expect(response).to have_http_status(:success)
    expect(response.body).to match("Usuario Uno")
    assert_select "a[href=?]", plan_personalizado_path(@plan)
    # Fase 5.14: sin "generado por ia" crudo ni menciones a IA en el copy
    expect(response.body).to match("Origen: análisis automático")
    expect(response.body).not_to match(/\bIA\b/)
  end
end
