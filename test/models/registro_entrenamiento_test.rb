require "test_helper"

class RegistroEntrenamientoTest < ActiveSupport::TestCase
  test "marcar! guarda estado por índice y preserva otros ejercicios" do
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)

    registro.marcar!(0, hecho: true, nota: " subí peso ", nombre: "Press banca")
    registro.marcar!(2, hecho: false, nota: "", nombre: "Sentadilla")

    assert_equal true, registro.reload.estado_de(0)["hecho"]
    assert_equal "subí peso", registro.estado_de(0)["nota"]     # strip
    assert_equal "Press banca", registro.estado_de(0)["nombre"]
    assert_equal false, registro.estado_de(2)["hecho"]
  end

  test "marcar! sobre el mismo índice reemplaza su estado" do
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    registro.marcar!(0, hecho: true, nota: "a", nombre: "Press")
    registro.marcar!(0, hecho: false, nota: "b", nombre: "Press")

    assert_equal false, registro.reload.estado_de(0)["hecho"]
    assert_equal "b", registro.estado_de(0)["nota"]
  end

  test "estado_de de un índice sin marcar es vacío" do
    registro = users(:one).registros_entrenamiento.new(fecha: Date.current)
    assert_equal({}, registro.estado_de(5))
  end

  test "la novedad del día convive con los checks (Fase 5.11)" do
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    registro.marcar!(0, hecho: true, nombre: "Press")
    registro.marcar_novedad!("  rodilla resentida  ")

    assert_equal "rodilla resentida", registro.reload.novedad
    assert_equal true, registro.estado_de(0)["hecho"]
  end

  test "una fila por usuario y fecha" do
    users(:one).registros_entrenamiento.create!(fecha: Date.current)
    repetido = users(:one).registros_entrenamiento.new(fecha: Date.current)

    assert_not repetido.valid?
    assert repetido.errors[:fecha].any?
  end
end
