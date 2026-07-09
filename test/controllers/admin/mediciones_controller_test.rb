require "test_helper"

class Admin::MedicionesControllerTest < ActionDispatch::IntegrationTest
  test "el staff toma una medición del miembro (queda como tomada_por)" do
    sign_in_as users(:entrenador)

    assert_difference "Medicion.count", 1 do
      post admin_user_mediciones_path(users(:one)),
           params: { medicion: { peso_kg: 74, talla_cm: 176, cintura_cm: 80 } }
    end
    assert_redirected_to admin_user_mediciones_path(users(:one))
    assert_equal users(:entrenador), users(:one).ultima_medicion.tomada_por
  end

  test "el staff ve el historial del miembro" do
    users(:one).mediciones.create!(peso_kg: 80, fecha: Date.current)
    sign_in_as users(:admin)

    get admin_user_mediciones_path(users(:one))
    assert_response :success
  end

  test "un miembro no puede ver ni tomar mediciones de otros" do
    sign_in_as users(:one)

    get admin_user_mediciones_path(users(:entrenador))
    assert_redirected_to root_path

    assert_no_difference "Medicion.count" do
      post admin_user_mediciones_path(users(:entrenador)), params: { medicion: { peso_kg: 90 } }
    end
    assert_redirected_to root_path
  end
end
