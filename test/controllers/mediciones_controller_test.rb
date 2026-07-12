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

  # Fase 5.12: el miembro agrega pesos de fechas pasadas y corrige los existentes
  test "el miembro agrega un peso de una fecha pasada" do
    sign_in_as users(:one)

    assert_difference "Medicion.count", 1 do
      post mediciones_path, params: { medicion: { fecha: 3.days.ago.to_date.iso8601, peso_kg: 74 } }
    end
    assert_equal 74, users(:one).mediciones.find_by(fecha: 3.days.ago.to_date).peso_kg.to_f
  end

  test "el miembro corrige un peso ya registrado sin duplicar ni perder la antropometría" do
    users(:one).mediciones.create!(fecha: Date.yesterday, peso_kg: 80, cintura_cm: 82,
                                   tomada_por: users(:entrenador))
    sign_in_as users(:one)

    assert_no_difference "Medicion.count" do
      post mediciones_path, params: { medicion: { fecha: Date.yesterday.iso8601, peso_kg: 78.5 } }
    end
    corregida = users(:one).mediciones.find_by(fecha: Date.yesterday)
    assert_equal 78.5, corregida.peso_kg.to_f
    assert_equal 82, corregida.cintura_cm.to_f # la antropometría del staff no se pierde
  end

  test "no permite registrar un peso futuro" do
    sign_in_as users(:one)

    assert_no_difference "Medicion.count" do
      post mediciones_path, params: { medicion: { fecha: Date.tomorrow.iso8601, peso_kg: 80 } }
    end
    assert_redirected_to progreso_path
  end
end
