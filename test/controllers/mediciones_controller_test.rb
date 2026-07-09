require "test_helper"

class MedicionesControllerTest < ActionDispatch::IntegrationTest
  test "el miembro auto-registra su peso (queda sin tomada_por externo)" do
    sign_in_as users(:one)

    assert_difference "Medicion.count", 1 do
      post mediciones_path, params: { medicion: { peso_kg: 77.4, grasa_pct: 18 } }
    end
    assert_redirected_to progreso_path

    medicion = users(:one).ultima_medicion
    assert_equal 77.4, medicion.peso_kg.to_f
    assert_equal users(:one), medicion.tomada_por
  end

  test "auto-registrar el mismo día actualiza el peso (no duplica)" do
    users(:one).mediciones.create!(peso_kg: 80, fecha: Date.current)
    sign_in_as users(:one)

    assert_no_difference "Medicion.count" do
      post mediciones_path, params: { medicion: { peso_kg: 79 } }
    end
    assert_equal 79, users(:one).ultima_medicion.peso_kg.to_f
  end
end
