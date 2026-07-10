require "test_helper"

class PlanesPersonalizadosControllerTest < ActionDispatch::IntegrationTest
  # Fase 5.11: con membresía activa y sin objetivo, Mi plan pregunta la meta.
  test "miembro con membresía activa sin objetivo ve el prompt de meta" do
    sign_in_as users(:one)

    get mi_plan_path

    assert_response :success
    assert_match "¿Cuál es tu meta?", response.body
    assert_nil users(:one).plan_aprobado
  end

  # Fase 5.11: con objetivo, el plan sugerido se crea (on-demand) y es editable
  # por su dueño, con seguimiento inline en la rutina.
  test "con objetivo se crea el plan sugerido editable con seguimiento inline" do
    ObjetivoNutricional.fijar_para(users(:one), tipo: "superavit", peso_kg: 70)
    sign_in_as users(:one)

    get mi_plan_path

    assert_response :success
    plan = users(:one).plan_aprobado
    assert plan.reglas?
    assert_equal 6, plan.dias.size
    assert_match "Incluido con tu membresía", response.body
    assert_select "input[name=?]", "ejercicio[nombre]"            # editor inline
    assert_match "seguimiento#marcar", response.body               # check por ejercicio
    assert_match "seguimiento#novedad", response.body              # novedad del día
  end

  test "volver a abrir Mi plan no duplica el plan sugerido" do
    ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)
    sign_in_as users(:one)

    get mi_plan_path
    assert_no_difference "PlanPersonalizado.count" do
      get mi_plan_path
    end
  end

  # El punto de notificación de borradores aparece para el staff (Fase 5.11)
  test "el staff ve el punto de borradores cuando hay pendientes" do
    PlanPersonalizado.create!(user: users(:one), generado_por: "ia",
                              estado: "generando", rutina: {}, plan_nutricional: {})
    sign_in_as users(:entrenador)

    get root_path
    assert_select "#punto_borradores span.bg-error"
  end

  test "sin pendientes el punto no se muestra" do
    sign_in_as users(:entrenador)
    get root_path
    assert_select "#punto_borradores span.bg-error", count: 0
  end
end
