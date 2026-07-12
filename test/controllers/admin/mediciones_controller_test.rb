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

  # Fase 5.13: "editar peso rápido" del popup no debe chocar con una medición
  # ya tomada el mismo día (upsert por fecha, preserva el resto de campos).
  test "tomar una segunda medición el mismo día corrige el peso sin duplicar" do
    users(:one).mediciones.create!(peso_kg: 80, cintura_cm: 82, fecha: Date.current, tomada_por: users(:admin))
    sign_in_as users(:entrenador)

    assert_no_difference "Medicion.count" do
      post admin_user_mediciones_path(users(:one)), params: { medicion: { peso_kg: 79 } }
    end
    corregida = users(:one).ultima_medicion
    assert_equal 79, corregida.peso_kg.to_f
    assert_equal 82, corregida.cintura_cm.to_f
    assert_equal users(:entrenador), corregida.tomada_por
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
