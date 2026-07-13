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

  # Fase 6.13: dashboard del miembro — datos básicos, gráficas de progreso
  test "el staff ve las gráficas de progreso en la ficha" do
    user = users(:one)
    ObjetivoNutricional.fijar_para(user, tipo: "deficit", peso_kg: 72)
    ObjetivoNutricional.fijar_para(user, tipo: "deficit", peso_kg: 70)
    RegistroCaloria.registrar(user, kcal: 1800)
    Acceso.registrar_para(user, user.membresia, ahora: Time.current.change(hour: 10))
    sign_in_as users(:entrenador)

    get admin_user_path(user)

    assert_response :success
    assert_select "svg[aria-label='Tendencia de peso']"
    assert_select "svg[aria-label='Calorías diarias contra el objetivo']"
    assert_select "svg[aria-label='Visitas al gimnasio por semana']"
  end

  test "el entrenador edita datos básicos pero no puede cambiar el rol" do
    sign_in_as users(:entrenador)
    patch admin_user_path(users(:one)), params: { user: { nombre: "Nuevo Nombre", rol: "admin" } }

    assert_redirected_to admin_user_path(users(:one))
    users(:one).reload
    assert_equal "Nuevo Nombre", users(:one).nombre
    assert_equal "miembro", users(:one).rol
  end

  test "el admin sí puede cambiar el rol" do
    sign_in_as users(:admin)
    patch admin_user_path(users(:one)), params: { user: { nombre: users(:one).nombre, rol: "entrenador" } }

    assert_redirected_to admin_user_path(users(:one))
    assert_equal "entrenador", users(:one).reload.rol
  end

  test "un miembro no puede editar el perfil de otro" do
    sign_in_as users(:one)
    patch admin_user_path(users(:two)), params: { user: { nombre: "Hackeado" } }

    assert_redirected_to root_path
    assert_not_equal "Hackeado", users(:two).reload.nombre
  end
end
