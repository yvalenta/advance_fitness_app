require "test_helper"

class RegistroCaloriaTest < ActiveSupport::TestCase
  test "registrar crea el registro del día" do
    registro = RegistroCaloria.registrar(users(:one), kcal: 1800)

    assert registro.persisted?
    assert_equal Date.current, registro.fecha
    assert_equal 1800, registro.kcal_consumidas
  end

  test "registrar el mismo día reemplaza el total (upsert, no duplica)" do
    RegistroCaloria.registrar(users(:one), kcal: 1200)

    assert_no_difference "RegistroCaloria.count" do
      RegistroCaloria.registrar(users(:one), kcal: 1750)
    end
    assert_equal 1750, users(:one).registros_calorias.find_by(fecha: Date.current).kcal_consumidas
  end

  test "kcal negativas no se guardan" do
    registro = RegistroCaloria.registrar(users(:one), kcal: -100)

    assert_not registro.persisted?
  end

  # Fase 5.8: el miembro puede anotar qué comió por comida (kcal + nota).
  test "registrar guarda el detalle de lo que comió el miembro" do
    detalle = { "comidas" => [ { "nombre" => "Desayuno", "kcal" => 300, "nota" => "cambié arroz por quinoa" } ] }
    registro = RegistroCaloria.registrar(users(:one), kcal: 300, detalle: detalle)

    assert registro.persisted?
    assert_equal detalle, registro.reload.detalle
  end

  test "registrar sin detalle deja el detalle por defecto vacío" do
    registro = RegistroCaloria.registrar(users(:one), kcal: 1500)

    assert_equal({}, registro.reload.detalle)
  end
end
