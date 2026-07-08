require "test_helper"

class Entrenador::BorradoresControllerTest < ActionDispatch::IntegrationTest
  RUTINA = { "dias" => [ { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [] } ] }.freeze
  NUTRICION = { "kcal_diarias" => 450, "comidas" => [ { "nombre" => "Desayuno", "descripcion" => "Huevos con arepa",
                 "kcal" => 450, "proteinas_g" => 30, "carbohidratos_g" => 40, "grasas_g" => 15 } ] }.freeze

  setup do
    @plan = PlanPersonalizado.create!(user: users(:one), rutina: RUTINA, plan_nutricional: NUTRICION)
  end

  test "un miembro no accede a la cola de borradores" do
    sign_in_as users(:one)
    get entrenador_borradores_path
    assert_redirected_to root_path
  end

  test "el entrenador ve la cola de revisión con enlace al editor" do
    sign_in_as users(:entrenador)
    get entrenador_borradores_path

    assert_response :success
    assert_match "Usuario Uno", response.body
    assert_select "a[href=?]", plan_personalizado_path(@plan)
  end
end
