require "test_helper"

class RegistrosCaloriasControllerTest < ActionDispatch::IntegrationTest
  test "el miembro registra su consumo con detalle por comida" do
    sign_in_as users(:one)
    detalle = { comidas: [ { nombre: "Desayuno", kcal: 300, nota: "quinoa" } ] }.to_json

    post registros_calorias_path, params: { registro_caloria: { kcal_consumidas: 300, detalle: detalle } }

    registro = users(:one).registros_calorias.find_by(fecha: Date.current)
    assert_equal 300, registro.kcal_consumidas
    assert_equal "quinoa", registro.detalle.dig("comidas", 0, "nota")
  end

  test "un detalle con JSON roto no rompe el registro del día" do
    sign_in_as users(:one)
    post registros_calorias_path, params: { registro_caloria: { kcal_consumidas: 200, detalle: "{roto" } }

    registro = users(:one).registros_calorias.find_by(fecha: Date.current)
    assert_equal 200, registro.kcal_consumidas
    assert_equal({}, registro.detalle)
  end

  # Fase 5.11: el historial es editable por fecha
  test "corrige las kcal de un día pasado sin duplicar" do
    RegistroCaloria.registrar(users(:one), kcal: 1500, fecha: Date.yesterday)
    sign_in_as users(:one)

    assert_no_difference "RegistroCaloria.count" do
      post registros_calorias_path,
           params: { registro_caloria: { kcal_consumidas: 1800, fecha: Date.yesterday.iso8601 } }
    end
    assert_equal 1800, users(:one).registros_calorias.find_by(fecha: Date.yesterday).kcal_consumidas
  end

  test "no permite registrar un día futuro" do
    sign_in_as users(:one)

    assert_no_difference "RegistroCaloria.count" do
      post registros_calorias_path,
           params: { registro_caloria: { kcal_consumidas: 1800, fecha: Date.tomorrow.iso8601 } }
    end
    assert_redirected_to objetivo_path
  end
end
