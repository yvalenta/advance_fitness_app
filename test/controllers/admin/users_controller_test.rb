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

  # Fase 6.11: el staff busca al miembro por nombre o correo
  test "el listado filtra por nombre o correo con ?q=" do
    sign_in_as users(:entrenador)

    get admin_users_path(q: users(:one).nombre)
    assert_response :success
    assert_match users(:one).email_address, response.body
    assert_no_match users(:two).email_address, response.body

    get admin_users_path(q: users(:two).email_address)
    assert_response :success
    assert_match users(:two).email_address, response.body
    assert_no_match users(:one).email_address, response.body
  end
end
