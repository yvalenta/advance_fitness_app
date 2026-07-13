require "test_helper"

class Ejercicios::CatalogoParaPromptTest < ActiveSupport::TestCase
  def crear_ejercicio(id, nombre, musculo, categoria, equipo: "barbell")
    Ejercicio.create!(dataset_id: id, nombre: nombre, nombre_en: nombre,
                      musculo: musculo, categoria: categoria, equipo: equipo)
  end

  test "agrupa por músculo con formato id | nombre (equipo) y excluye cardio" do
    press = crear_ejercicio("0001", "Press de banca", "pecho", "chest")
    crear_ejercicio("0002", "Correr", "otro", "cardio")

    texto = Ejercicios::CatalogoParaPrompt.para

    assert_match "PECHO:", texto
    assert_match "#{press.id} | Press de banca (barbell)", texto
    assert_no_match(/Correr/, texto)
  end

  test "prioriza los ejercicios curados y respeta el límite por músculo" do
    curado = crear_ejercicio("0010", "ZZ curado", "pecho", "chest")
    PlantillaEjercicio.create!(musculo: "pecho", nombre: "Mi plantilla", repeticiones: "10", ejercicio: curado)
    5.times { |i| crear_ejercicio("002#{i}", "AA relleno #{i}", "pecho", "chest") }

    texto = Ejercicios::CatalogoParaPrompt.para(limite_por_musculo: 3)

    lineas = texto.lines.map(&:strip) - [ "PECHO:" ]
    assert_equal 3, lineas.count(&:present?)
    assert_equal "#{curado.id} | ZZ curado (barbell)", lineas.first
  end
end
