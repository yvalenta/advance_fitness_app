require "test_helper"

class PlantillaComidaTest < ActiveSupport::TestCase
  test "valida tipo, contenido y kcal positivas" do
    plantilla = PlantillaComida.new(tipo: "brunch", nombre: "", descripcion: "", kcal: 0)

    assert_not plantilla.valid?
    assert plantilla.errors[:tipo].any?
    assert plantilla.errors[:nombre].any?
    assert plantilla.errors[:descripcion].any?
    assert plantilla.errors[:kcal].any?
  end

  test "el nombre es único dentro del tipo pero se repite entre tipos" do
    existente = plantillas_comida(:desayuno_avena)

    duplicada = PlantillaComida.new(tipo: existente.tipo, nombre: existente.nombre,
                                    descripcion: "otra", kcal: 300)
    assert_not duplicada.valid?

    otro_tipo = PlantillaComida.new(tipo: "snack", nombre: existente.nombre,
                                    descripcion: "otra", kcal: 300)
    assert otro_tipo.valid?
  end

  test "tipo_para clasifica los nombres de comidas del plan" do
    assert_equal "desayuno", PlantillaComida.tipo_para("Desayuno")
    assert_equal "almuerzo", PlantillaComida.tipo_para("Almuerzo")
    assert_equal "cena", PlantillaComida.tipo_para("Cena")
    assert_equal "cena", PlantillaComida.tipo_para("Antes de Dormir (Opcional)")
    assert_equal "snack", PlantillaComida.tipo_para("Media Mañana")
    assert_equal "snack", PlantillaComida.tipo_para("Merienda")
  end
end
