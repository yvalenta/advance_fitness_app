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
end
