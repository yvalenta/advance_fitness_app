require "test_helper"

class PlanesPersonalizadosControllerTest < ActionDispatch::IntegrationTest
  # Fase 5.9: un miembro con membresía activa (no premium) recibe el plan básico
  # por reglas. Fase 5.10: además ve la tarjeta de seguimiento del día.
  test "miembro con membresía activa ve el plan básico incluido y el seguimiento" do
    sign_in_as users(:one) # membresía activa por fixture, sin suscripción

    get mi_plan_path

    assert_response :success
    assert_match "Incluido con tu membresía", response.body
    assert_match "Rutina semanal", response.body
    assert_select "turbo-frame#seguimiento"
    assert_match "Seguimiento", response.body
  end
end
