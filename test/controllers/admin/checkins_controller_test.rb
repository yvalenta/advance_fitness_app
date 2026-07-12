require "test_helper"

class Admin::CheckinsControllerTest < ActionDispatch::IntegrationTest
  test "un miembro no accede al panel de check-in" do
    sign_in_as users(:one)
    get admin_checkins_path
    assert_redirected_to root_path
  end

  test "staff registra el check-in de una membresía activa" do
    sign_in_as users(:entrenador)

    assert_difference "Acceso.count", 1 do
      post admin_checkins_path, params: { user_id: users(:one).id }
    end
    assert_redirected_to admin_checkins_path
    assert_equal "checkin", Acceso.recientes.first.tipo
  end

  test "membresía vencida no registra acceso y pide renovación" do
    sign_in_as users(:admin)

    assert_no_difference "Acceso.count" do
      post admin_checkins_path, params: { user_id: users(:two).id }
    end
    assert_match(/renovación/, flash[:alert])
  end

  test "miembro sin membresía no registra acceso" do
    sign_in_as users(:admin)

    assert_no_difference "Acceso.count" do
      post admin_checkins_path, params: { user_id: users(:entrenador).id }
    end
    assert_match(/no tiene membresía/, flash[:alert])
  end

  # Regla de negocio (SDD §10): el plan personalizado reemplaza la mensualidad.
  test "un miembro premium sin membresía activa entra igual" do
    sign_in_as users(:admin)
    # two tiene la membresía vencida; le damos plan personalizado activo
    Suscripcion.create!(user: users(:two), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)

    assert_difference "Acceso.count", 1 do
      post admin_checkins_path, params: { user_id: users(:two).id }
    end
    assert_match(/plan personalizado/, flash[:notice])
  end

  # Fase 5.13: cada fila de miembro trae los datos para el popup de resumen
  # (peso rápido, check-in, ficha) sin romper el acento del eyebrow.
  test "el índice trae el popup de resumen con los data-* por miembro" do
    sign_in_as users(:entrenador)

    get admin_checkins_path(q: "Uno")

    assert_response :success
    assert_match "Administración", response.body
    assert_select "dialog[data-resumen-miembro-target=dialogo]"
    assert_select "[data-resumen-miembro-id-param=?]", users(:one).id.to_s
    assert_select "[data-resumen-miembro-medicion-url-param=?]", admin_user_mediciones_path(users(:one))
    assert_select "[data-resumen-miembro-perfil-url-param=?]", admin_user_path(users(:one))
  end

  test "el badge de horario no se corta en una sola línea" do
    Acceso.registrar_para(users(:one), users(:one).membresia, ahora: Time.current)
    sign_in_as users(:entrenador)

    get admin_checkins_path
    assert_select "span.badge.whitespace-nowrap", minimum: 1
  end
end
