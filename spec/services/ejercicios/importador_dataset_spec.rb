require "rails_helper"

RSpec.describe Ejercicios::ImportadorDataset, type: :model do
  MUESTRA = Rails.root.join("test/fixtures/files/exercises_muestra.json").to_s

  it "importa el dataset con el músculo mapeado y los pasos en español" do
    resumen = Ejercicios::ImportadorDataset.importar(MUESTRA)

    expect(resumen).to eq({ creados: 4, actualizados: 0, sin_cambio: 0 })

    press = Ejercicio.find_by(dataset_id: "0025")
    expect(press.nombre_en).to eq("barbell bench press")
    expect(press.nombre).to eq("barbell bench press") # aún sin traducir
    expect(press.musculo).to eq("pecho")
    expect(press.equipo).to eq("barbell")
    expect(press.imagen_ruta).to eq("images/0025-AbC1234.jpg")
    expect(press.gif_ruta).to eq("videos/0025-AbC1234.gif")
    expect(press.instrucciones.size).to eq(3) # instruction_steps.es
    expect(press.instrucciones.first).to match("banco plano")

    expect(Ejercicio.find_by(dataset_id: "0031").musculo).to eq("biceps")
    expect(Ejercicio.find_by(dataset_id: "1160").musculo).to eq("otro")
  end

  it "sin instruction_steps parte el texto corrido en oraciones" do
    Ejercicios::ImportadorDataset.importar(MUESTRA)

    curl = Ejercicio.find_by(dataset_id: "0031")
    expect(curl.instrucciones.size).to eq(2)
    expect(curl.instrucciones.first).to match("agarre supino")
  end

  it "es idempotente y no pisa un nombre ya traducido" do
    Ejercicios::ImportadorDataset.importar(MUESTRA)
    Ejercicio.find_by(dataset_id: "0025").update!(nombre: "Press de banca con barra")

    resumen = Ejercicios::ImportadorDataset.importar(MUESTRA)

    expect(resumen[:creados]).to eq(0)
    expect(resumen[:sin_cambio] + resumen[:actualizados]).to eq(4)
    expect(Ejercicio.find_by(dataset_id: "0025").nombre).to eq("Press de banca con barra")
    expect(Ejercicio.count).to eq(4)
  end
end
