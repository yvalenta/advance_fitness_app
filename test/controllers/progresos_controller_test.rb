require "test_helper"

class ProgresosControllerTest < ActionDispatch::IntegrationTest
  test "requiere sesión" do
    get progreso_path
    assert_redirected_to new_session_path
  end

  test "muestra las gráficas con los datos del miembro" do
    user = users(:one)
    ObjetivoNutricional.fijar_para(user, tipo: "deficit", peso_kg: 72)
    ObjetivoNutricional.fijar_para(user, tipo: "deficit", peso_kg: 70)
    RegistroCaloria.registrar(user, kcal: 1800)
    Acceso.registrar_para(user, user.membresia, ahora: Time.current.change(hour: 10))

    sign_in_as user
    get progreso_path

    assert_response :success
    assert_match "Tendencia de peso", response.body
    assert_match "70.0 kg", response.body                       # peso actual
    assert_select "svg[aria-label='Tendencia de peso']"
    assert_select "svg[aria-label='Calorías diarias contra el objetivo']"
    assert_select "svg[aria-label='Visitas al gimnasio por semana']"
    assert_match "1 de 1 días registrados en meta", response.body
  end

  test "sin datos muestra estados vacíos con CTA" do
    sign_in_as users(:two)
    get progreso_path

    assert_response :success
    assert_match "al menos dos objetivos", response.body
    assert_match "Fija tu objetivo calórico", response.body
    assert_match "Tus check-ins en recepción aparecerán aquí", response.body
  end
end
