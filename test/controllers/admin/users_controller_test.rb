require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "un miembro no accede a la ficha de otro" do
    sign_in_as users(:one)
    get admin_user_path(users(:two))
    assert_redirected_to root_path
  end

  test "el staff ve la ficha con la card de plan" do
    sign_in_as users(:entrenador)
    get admin_user_path(users(:one))

    assert_response :success
    assert_match "Sin plan aún", response.body
  end

  # Fase 5.13: la ficha del miembro enlaza directo a su plan (editor de staff)
  test "con un plan, la ficha enlaza al editor del plan" do
    plan = PlanPersonalizado.create!(user: users(:one), generado_por: "reglas",
                                     estado: "aprobado", rutina: { "dias" => [] }, plan_nutricional: {})
    sign_in_as users(:entrenador)

    get admin_user_path(users(:one))

    assert_response :success
    assert_select "a[href=?]", plan_personalizado_path(plan)
  end
end
