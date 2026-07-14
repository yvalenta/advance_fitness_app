require "rails_helper"

RSpec.describe "Mediciones", type: :request do
  it "el miembro auto-registra su peso (queda sin tomada_por externo)" do
    sign_in_as users(:one)

    expect {
      post mediciones_path, params: { medicion: { peso_kg: 77.4, grasa_pct: 18 } }
    }.to change(Medicion, :count).by(1)
    expect(response).to redirect_to(progreso_path)

    medicion = users(:one).ultima_medicion
    expect(medicion.peso_kg.to_f).to eq(77.4)
    expect(medicion.tomada_por).to eq(users(:one))
  end

  it "auto-registrar el mismo día actualiza el peso (no duplica)" do
    users(:one).mediciones.create!(peso_kg: 80, fecha: Date.current)
    sign_in_as users(:one)

    expect {
      post mediciones_path, params: { medicion: { peso_kg: 79 } }
    }.not_to change(Medicion, :count)
    expect(users(:one).ultima_medicion.peso_kg.to_f).to eq(79)
  end

  # Fase 5.12: el miembro agrega pesos de fechas pasadas y corrige los existentes
  it "el miembro agrega un peso de una fecha pasada" do
    sign_in_as users(:one)

    expect {
      post mediciones_path, params: { medicion: { fecha: 3.days.ago.to_date.iso8601, peso_kg: 74 } }
    }.to change(Medicion, :count).by(1)
    expect(users(:one).mediciones.find_by(fecha: 3.days.ago.to_date).peso_kg.to_f).to eq(74)
  end

  it "el miembro corrige un peso ya registrado sin duplicar ni perder la antropometría" do
    users(:one).mediciones.create!(fecha: Date.yesterday, peso_kg: 80, cintura_cm: 82,
                                   tomada_por: users(:entrenador))
    sign_in_as users(:one)

    expect {
      post mediciones_path, params: { medicion: { fecha: Date.yesterday.iso8601, peso_kg: 78.5 } }
    }.not_to change(Medicion, :count)
    corregida = users(:one).mediciones.find_by(fecha: Date.yesterday)
    expect(corregida.peso_kg.to_f).to eq(78.5)
    expect(corregida.cintura_cm.to_f).to eq(82) # la antropometría del staff no se pierde
  end

  it "no permite registrar un peso futuro" do
    sign_in_as users(:one)

    expect {
      post mediciones_path, params: { medicion: { fecha: Date.tomorrow.iso8601, peso_kg: 80 } }
    }.not_to change(Medicion, :count)
    expect(response).to redirect_to(progreso_path)
  end
end
