require "rails_helper"

RSpec.describe RegistroCaloria, type: :model do
  it "registrar crea el registro del día" do
    registro = RegistroCaloria.registrar(users(:one), kcal: 1800)

    expect(registro.persisted?).to be_truthy
    expect(registro.fecha).to eq(Date.current)
    expect(registro.kcal_consumidas).to eq(1800)
  end

  it "registrar el mismo día reemplaza el total (upsert, no duplica)" do
    RegistroCaloria.registrar(users(:one), kcal: 1200)

    expect {
      RegistroCaloria.registrar(users(:one), kcal: 1750)
    }.not_to change(RegistroCaloria, :count)
    expect(users(:one).registros_calorias.find_by(fecha: Date.current).kcal_consumidas).to eq(1750)
  end

  it "kcal negativas no se guardan" do
    registro = RegistroCaloria.registrar(users(:one), kcal: -100)

    expect(registro.persisted?).to be_falsey
  end

  # Fase 5.8: el miembro puede anotar qué comió por comida (kcal + nota).
  it "registrar guarda el detalle de lo que comió el miembro" do
    detalle = { "comidas" => [ { "nombre" => "Desayuno", "kcal" => 300, "nota" => "cambié arroz por quinoa" } ] }
    registro = RegistroCaloria.registrar(users(:one), kcal: 300, detalle: detalle)

    expect(registro.persisted?).to be_truthy
    expect(registro.reload.detalle).to eq(detalle)
  end

  it "registrar sin detalle deja el detalle por defecto vacío" do
    registro = RegistroCaloria.registrar(users(:one), kcal: 1500)

    expect(registro.reload.detalle).to eq({})
  end
end
