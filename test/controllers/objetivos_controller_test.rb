require "test_helper"

class ObjetivosControllerTest < ActionDispatch::IntegrationTest
  # Criterio de aceptación Fase 4 (SDD §11): al fijar "bajar de peso" veo mi
  # objetivo kcal y el faltante del día se actualiza al registrar consumo.
  test "fijar déficit muestra el objetivo y el registro de consumo actualiza el faltante" do
    sign_in_as users(:one)

    post objetivo_path, params: { objetivo_nutricional: { tipo: "deficit", peso_kg: 70 } }
    assert_redirected_to objetivo_path

    get objetivo_path
    assert_response :success
    assert_match "2.138", response.body   # objetivo kcal (TDEE 2638 − 500)

    post registros_calorias_path, params: { registro_caloria: { kcal_consumidas: 1200 } }
    follow_redirect!
    assert_select "#kcal-restantes", text: /938/
  end

  test "sin perfil completo redirige a completar perfil" do
    sign_in_as users(:two)

    get new_objetivo_path
    assert_redirected_to edit_perfil_path
  end

  test "sin objetivo la página invita a fijarlo" do
    sign_in_as users(:one)

    get objetivo_path
    assert_response :success
    assert_match "Fijar mi objetivo", response.body
  end

  test "requiere sesión" do
    get objetivo_path
    assert_redirected_to new_session_path
  end
end
