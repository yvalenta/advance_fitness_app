require "test_helper"

class GestionPlanesControllerTest < ActionDispatch::IntegrationTest
  RUTINA = { "dias" => [ { "dia" => "lunes", "enfoque" => "pecho",
                           "ejercicios" => [ { "nombre" => "Press banca", "series" => 4,
                                               "repeticiones" => "8-10", "descanso_seg" => 90 } ] } ] }.freeze
  NUTRICION = { "kcal_diarias" => 450, "comidas" => [ { "nombre" => "Desayuno", "descripcion" => "Huevos con arepa",
                 "kcal" => 450, "proteinas_g" => 30, "carbohidratos_g" => 40, "grasas_g" => 15 } ] }.freeze

  setup do
    @plan = PlanPersonalizado.create!(user: users(:one), rutina: RUTINA, plan_nutricional: NUTRICION)
  end

  test "el editor muestra la comida editable y el historial" do
    sign_in_as users(:entrenador)
    get plan_personalizado_path(@plan)

    assert_response :success
    assert_select "input[name='comida[nombre]'][value=Desayuno]"
    assert_select "textarea[name='comida[descripcion]']", text: /Huevos con arepa/
    assert_match "Historial del miembro", response.body
  end

  test "el admin también puede abrir el editor" do
    sign_in_as users(:admin)
    get plan_personalizado_path(@plan)
    assert_response :success
  end

  test "un miembro no puede abrir el editor de un plan" do
    sign_in_as users(:one)
    get plan_personalizado_path(@plan)
    assert_redirected_to root_path
  end

  # Criterio de aceptación F5 (SDD §11): el miembro ve el plan SOLO tras publicar.
  test "el miembro ve su plan solo después de publicar" do
    Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)

    sign_in_as users(:one)
    get mi_plan_path
    assert_no_match "Press banca", response.body
    assert_match "en preparación", response.body

    sign_in_as users(:entrenador)
    post publicar_plan_personalizado_path(@plan)
    assert_equal "aprobado", @plan.reload.estado
    assert_equal users(:entrenador), @plan.aprobado_por

    sign_in_as users(:one)
    get mi_plan_path
    assert_match "Press banca", response.body
    assert_match "Huevos con arepa", response.body
  end

  test "el modo avanzado guarda el JSON de la rutina" do
    sign_in_as users(:entrenador)
    ajustada = RUTINA.deep_dup
    ajustada["dias"][0]["ejercicios"][0]["series"] = 5

    patch plan_personalizado_path(@plan), params: { rutina: ajustada.to_json }

    assert_equal 5, @plan.reload.rutina.dig("dias", 0, "ejercicios", 0, "series")
    assert_redirected_to plan_personalizado_path(@plan)
  end

  test "JSON inválido en modo avanzado avisa y no rompe" do
    sign_in_as users(:entrenador)
    patch plan_personalizado_path(@plan), params: { rutina: "{rota" }

    assert_match(/no es válido/, flash[:alert])
  end
end
