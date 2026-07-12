require "test_helper"

class GestionEjerciciosControllerTest < ActionDispatch::IntegrationTest
  RUTINA = { "dias" => [
    { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [
      { "nombre" => "Press banca", "series" => 4, "repeticiones" => "8-10", "descanso_seg" => 90 }
    ] }
  ] }.freeze
  NUTRICION = { "kcal_diarias" => 100, "comidas" => [] }.freeze

  setup do
    @plan = PlanPersonalizado.create!(user: users(:one), rutina: RUTINA, plan_nutricional: NUTRICION)
  end

  test "el staff autosalva un ejercicio por día e índice" do
    sign_in_as users(:entrenador)

    patch plan_personalizado_dia_ejercicio_path(@plan, 0, 0), as: :json,
          params: { ejercicio: { nombre: "Press inclinado", series: "5", repeticiones: "6-8", descanso_seg: "120" } }

    assert_response :success
    ej = @plan.reload.ejercicios_de(0).first
    assert_equal "Press inclinado", ej["nombre"]
    assert_equal 5, ej["series"]
  end

  test "agregar y eliminar ejercicios de un día" do
    sign_in_as users(:admin)

    assert_difference -> { @plan.reload.ejercicios_de(0).size }, 1 do
      post plan_personalizado_dia_ejercicios_path(@plan, 0), as: :json, params: { ejercicio: { nombre: "Aperturas" } }
    end
    assert_response :created

    assert_difference -> { @plan.reload.ejercicios_de(0).size }, -1 do
      delete plan_personalizado_dia_ejercicio_path(@plan, 0, 0), as: :json
    end
  end

  test "un índice de ejercicio inexistente responde 404" do
    sign_in_as users(:entrenador)
    patch plan_personalizado_dia_ejercicio_path(@plan, 0, 9), as: :json, params: { ejercicio: { series: "3" } }
    assert_response :not_found
  end

  test "un miembro no puede editar la rutina de un plan sin publicar" do
    sign_in_as users(:one)
    assert_no_changes -> { @plan.reload.ejercicios_de(0).first["series"] } do
      patch plan_personalizado_dia_ejercicio_path(@plan, 0, 0), as: :json, params: { ejercicio: { series: "9" } }
    end
    assert_response :redirect
  end

  # Fase 5.12: publicado, el dueño edita la rutina aunque sea de IA
  test "el dueño edita un ejercicio de su plan de IA ya publicado" do
    publicado = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "aprobado",
                                          aprobado_por: users(:entrenador), rutina: RUTINA,
                                          plan_nutricional: { "kcal_diarias" => 0, "comidas" => [] })
    sign_in_as users(:one)

    patch plan_personalizado_dia_ejercicio_path(publicado, 0, 0), as: :json, params: { ejercicio: { series: "9" } }

    assert_response :success
    assert_equal 9, publicado.reload.ejercicios_de(0).first["series"]
  end
end
