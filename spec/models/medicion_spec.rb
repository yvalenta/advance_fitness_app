require "rails_helper"

RSpec.describe Medicion, type: :model do
  it "exige peso y una por fecha" do
    users(:one).mediciones.create!(peso_kg: 80, fecha: Date.current)

    sin_peso = users(:one).mediciones.new(fecha: Date.tomorrow)
    expect(sin_peso.valid?).to be_falsey
    expect(sin_peso.errors[:peso_kg].any?).to be_truthy

    repetida = users(:one).mediciones.new(peso_kg: 79, fecha: Date.current)
    expect(repetida.valid?).to be_falsey
    expect(repetida.errors[:fecha].any?).to be_truthy
  end

  it "el IMC es columna generada en Postgres" do
    medicion = users(:one).mediciones.create!(peso_kg: 80, talla_cm: 178, fecha: Date.current)

    expect(medicion.reload.imc).to be_within(0.05).of(25.2)
  end

  it "sin talla el IMC queda nulo (no rompe por división por cero)" do
    medicion = users(:one).mediciones.create!(peso_kg: 80, talla_cm: nil, fecha: Date.current)

    expect(medicion.reload.imc).to be_nil
  end

  it "presentes devuelve pares etiqueta/valor solo de las medidas cargadas" do
    medicion = users(:one).mediciones.new(peso_kg: 80, cintura_cm: 82, cadera_cm: nil)

    presentes = medicion.presentes(Medicion::PERIMETROS)
    expect(presentes).to include([ "Cintura", 82 ])
    expect(presentes.any? { |etiqueta, _| etiqueta == "Cadera" }).to be_falsey
  end

  it "ultima_medicion es la más reciente por fecha" do
    users(:one).mediciones.create!(peso_kg: 80, fecha: 3.days.ago)
    reciente = users(:one).mediciones.create!(peso_kg: 78, fecha: Date.current)

    expect(users(:one).ultima_medicion).to eq(reciente)
  end
end
