require "test_helper"

class Entrenador::BorradoresControllerTest < ActionDispatch::IntegrationTest
  RUTINA = { "dias" => [ { "dia" => "lunes", "enfoque" => "pecho",
                           "ejercicios" => [ { "nombre" => "Press banca", "series" => 4,
                                               "repeticiones" => "8-10", "descanso_seg" => 90 } ] } ] }.freeze
  NUTRICION = { "kcal_diarias" => 2100,
                "comidas" => [ { "nombre" => "Desayuno", "descripcion" => "Huevos con arepa",
                                 "kcal" => 450, "proteinas_g" => 30, "carbohidratos_g" => 40, "grasas_g" => 15 } ] }.freeze

  setup do
    @plan = PlanPersonalizado.create!(user: users(:one), rutina: RUTINA, plan_nutricional: NUTRICION)
  end

  test "un miembro no accede a los borradores" do
    sign_in_as users(:one)
    get entrenador_borradores_path
    assert_redirected_to root_path
  end

  test "el entrenador ve la cola de revisión" do
    sign_in_as users(:entrenador)
    get entrenador_borradores_path
    assert_response :success
    assert_match "Usuario Uno", response.body
  end

  # Criterio de aceptación F5 (SDD §11): un miembro premium recibe el plan
  # generado por IA SOLO después de la aprobación del entrenador.
  test "el miembro ve su plan solo tras la aprobación del entrenador" do
    Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)

    sign_in_as users(:one)
    get mi_plan_path
    assert_response :success
    assert_no_match "Press banca", response.body      # borrador: invisible
    assert_match "en preparación", response.body

    sign_in_as users(:entrenador)
    post entrenador_borrador_aprobacion_path(@plan)
    assert_equal "aprobado", @plan.reload.estado
    assert_equal users(:entrenador), @plan.aprobado_por

    sign_in_as users(:one)
    get mi_plan_path
    assert_match "Press banca", response.body          # aprobado: visible
    assert_match "Huevos con arepa", response.body
  end

  test "la aprobación acepta JSON ajustado por el entrenador" do
    sign_in_as users(:entrenador)
    ajustada = RUTINA.deep_dup
    ajustada["dias"][0]["ejercicios"][0]["series"] = 5

    post entrenador_borrador_aprobacion_path(@plan), params: { rutina: ajustada.to_json }

    assert_equal 5, @plan.reload.rutina.dig("dias", 0, "ejercicios", 0, "series")
    assert @plan.aprobado?
  end

  test "JSON inválido no aprueba y avisa" do
    sign_in_as users(:entrenador)

    post entrenador_borrador_aprobacion_path(@plan), params: { rutina: "{rota" }

    assert @plan.reload.borrador?
    assert_match(/no es válido/, flash[:alert])
  end
end
