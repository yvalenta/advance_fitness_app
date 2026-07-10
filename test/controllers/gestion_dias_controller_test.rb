require "test_helper"

class GestionDiasControllerTest < ActionDispatch::IntegrationTest
  RUTINA = { "dias" => [
    { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [
      { "nombre" => "Press banca", "series" => 4, "repeticiones" => "8-10", "descanso_seg" => 90 }
    ] }
  ] }.freeze

  setup do
    @plan = PlanPersonalizado.create!(user: users(:one), rutina: RUTINA,
                                      plan_nutricional: { "kcal_diarias" => 100, "comidas" => [] })
  end

  # Fase 5.11: aplicar una sesión completa por músculo refresca solo ese día
  test "el staff aplica una sesión por músculo y recibe el turbo_stream del día" do
    sign_in_as users(:entrenador)

    patch plan_personalizado_dia_path(@plan, 0), as: :json,
          params: { dia: { sesion_musculo: "pierna" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "turbo-stream", response.body
    assert_match "dia_editor_0", response.body

    dia = @plan.reload.dias[0]
    assert_equal "Pierna", dia["enfoque"]
    assert_includes dia["ejercicios"].map { |e| e["nombre"] }, "Sentadilla con barra"
  end

  test "una sesión de un músculo sin plantillas responde 404 y no toca el plan" do
    sign_in_as users(:entrenador)

    patch plan_personalizado_dia_path(@plan, 0), as: :json, params: { dia: { sesion_musculo: "gluteo" } }

    assert_response :not_found
    assert_equal "pecho", @plan.reload.dias[0]["enfoque"]
  end

  # Fase 5.11: el dueño de un plan sugerido (reglas) también puede editarlo
  test "el miembro dueño de un plan reglas edita el enfoque y aplica sesiones" do
    plan = PlanPersonalizado.create!(user: users(:one), generado_por: "reglas",
                                     estado: "aprobado", rutina: RUTINA, plan_nutricional: {})
    sign_in_as users(:one)

    patch plan_personalizado_dia_path(plan, 0), as: :json, params: { dia: { enfoque: "Pecho fuerte" } }
    assert_response :success
    assert_equal "Pecho fuerte", plan.reload.dias[0]["enfoque"]
  end

  test "el miembro NO edita su plan de IA ni el plan reglas de otro" do
    sign_in_as users(:one)

    # Su propio plan pero generado por IA (borrador del flujo premium)
    patch plan_personalizado_dia_path(@plan, 0), as: :json, params: { dia: { enfoque: "hackeo" } }
    assert_response :redirect
    assert_equal "pecho", @plan.reload.dias[0]["enfoque"]

    ajeno = PlanPersonalizado.create!(user: users(:two), generado_por: "reglas",
                                      estado: "aprobado", rutina: RUTINA, plan_nutricional: {})
    patch plan_personalizado_dia_path(ajeno, 0), as: :json, params: { dia: { enfoque: "hackeo" } }
    assert_response :redirect
  end
end
