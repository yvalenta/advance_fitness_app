require "test_helper"

class MedicionTest < ActiveSupport::TestCase
  test "exige peso y una por fecha" do
    users(:one).mediciones.create!(peso_kg: 80, fecha: Date.current)

    sin_peso = users(:one).mediciones.new(fecha: Date.tomorrow)
    assert_not sin_peso.valid?
    assert sin_peso.errors[:peso_kg].any?

    repetida = users(:one).mediciones.new(peso_kg: 79, fecha: Date.current)
    assert_not repetida.valid?
    assert repetida.errors[:fecha].any?
  end

  test "el IMC es columna generada en Postgres" do
    medicion = users(:one).mediciones.create!(peso_kg: 80, talla_cm: 178, fecha: Date.current)

    assert_in_delta 25.2, medicion.reload.imc, 0.05
  end

  test "sin talla el IMC queda nulo (no rompe por división por cero)" do
    medicion = users(:one).mediciones.create!(peso_kg: 80, talla_cm: nil, fecha: Date.current)

    assert_nil medicion.reload.imc
  end

  test "presentes devuelve pares etiqueta/valor solo de las medidas cargadas" do
    medicion = users(:one).mediciones.new(peso_kg: 80, cintura_cm: 82, cadera_cm: nil)

    presentes = medicion.presentes(Medicion::PERIMETROS)
    assert_includes presentes, [ "Cintura", 82 ]
    assert_not presentes.any? { |etiqueta, _| etiqueta == "Cadera" }
  end

  test "ultima_medicion es la más reciente por fecha" do
    users(:one).mediciones.create!(peso_kg: 80, fecha: 3.days.ago)
    reciente = users(:one).mediciones.create!(peso_kg: 78, fecha: Date.current)

    assert_equal reciente, users(:one).ultima_medicion
  end
end
