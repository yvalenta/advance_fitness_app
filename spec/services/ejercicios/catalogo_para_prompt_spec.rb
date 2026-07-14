require "rails_helper"

RSpec.describe Ejercicios::CatalogoParaPrompt, type: :model do
  def crear_ejercicio(id, nombre, musculo, categoria, equipo: "barbell")
    Ejercicio.create!(dataset_id: id, nombre: nombre, nombre_en: nombre,
                      musculo: musculo, categoria: categoria, equipo: equipo)
  end

  it "agrupa por músculo con formato id | nombre (equipo) y excluye cardio" do
    press = crear_ejercicio("0001", "Press de banca", "pecho", "chest")
    crear_ejercicio("0002", "Correr", "otro", "cardio")

    texto = Ejercicios::CatalogoParaPrompt.para

    expect(texto).to include("PECHO:")
    expect(texto).to include("#{press.id} | Press de banca (barbell)")
    expect(texto).not_to match(/Correr/)
  end

  it "prioriza los ejercicios curados y respeta el límite por músculo" do
    curado = crear_ejercicio("0010", "ZZ curado", "pecho", "chest")
    PlantillaEjercicio.create!(musculo: "pecho", nombre: "Mi plantilla", repeticiones: "10", ejercicio: curado)
    5.times { |i| crear_ejercicio("002#{i}", "AA relleno #{i}", "pecho", "chest") }

    texto = Ejercicios::CatalogoParaPrompt.para(limite_por_musculo: 3)

    lineas = texto.lines.map(&:strip) - [ "PECHO:" ]
    expect(lineas.count(&:present?)).to eq(3)
    expect(lineas.first).to eq("#{curado.id} | ZZ curado (barbell)")
  end
end
