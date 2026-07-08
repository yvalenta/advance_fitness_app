require "test_helper"

class GestionComidasControllerTest < ActionDispatch::IntegrationTest
  RUTINA = { "dias" => [] }.freeze
  NUTRICION = { "kcal_diarias" => 900, "comidas" => [
    { "nombre" => "Desayuno", "descripcion" => "Huevos", "kcal" => 400,
      "proteinas_g" => 30, "carbohidratos_g" => 40, "grasas_g" => 15 },
    { "nombre" => "Cena", "descripcion" => "Salmón", "kcal" => 500,
      "proteinas_g" => 35, "carbohidratos_g" => 40, "grasas_g" => 22 }
  ] }.freeze

  setup do
    @plan = PlanPersonalizado.create!(user: users(:one), rutina: RUTINA, plan_nutricional: NUTRICION)
  end

  test "el staff autosalva una comida por índice y recibe el total recalculado" do
    sign_in_as users(:entrenador)

    patch plan_personalizado_comida_path(@plan, 0), as: :json,
          params: { comida: { nombre: "Desayuno power", descripcion: "Avena", kcal: "520",
                              proteinas_g: "35", carbohidratos_g: "60", grasas_g: "12" } }

    assert_response :success
    assert_equal 1020, response.parsed_body["kcal_diarias"]     # 520 + 500
    assert_equal "Desayuno power", @plan.reload.comidas.first["nombre"]
  end

  test "agregar y eliminar comidas cambia el tamaño del plan" do
    sign_in_as users(:admin)

    assert_difference -> { @plan.reload.comidas.size }, 1 do
      post plan_personalizado_comidas_path(@plan), as: :json,
           params: { comida: { nombre: "Snack", kcal: "150" } }
    end
    assert_response :created

    assert_difference -> { @plan.reload.comidas.size }, -1 do
      delete plan_personalizado_comida_path(@plan, 0), as: :json
    end
    assert_response :success
  end

  test "un índice inexistente responde 404 sin romper" do
    sign_in_as users(:entrenador)
    patch plan_personalizado_comida_path(@plan, 99), as: :json, params: { comida: { kcal: "100" } }
    assert_response :not_found
  end

  test "un miembro no puede editar las comidas de un plan" do
    sign_in_as users(:one)

    assert_no_changes -> { @plan.reload.comidas.first["kcal"] } do
      patch plan_personalizado_comida_path(@plan, 0), as: :json, params: { comida: { kcal: "999" } }
    end
    assert_response :redirect
  end
end
