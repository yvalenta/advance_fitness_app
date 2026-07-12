require "test_helper"

class Ejercicios::ImportadorDatasetTest < ActiveSupport::TestCase
  MUESTRA = Rails.root.join("test/fixtures/files/exercises_muestra.json").to_s

  test "importa el dataset con el músculo mapeado y los pasos en español" do
    resumen = Ejercicios::ImportadorDataset.importar(MUESTRA)

    assert_equal({ creados: 4, actualizados: 0, sin_cambio: 0 }, resumen)

    press = Ejercicio.find_by(dataset_id: "0025")
    assert_equal "barbell bench press", press.nombre_en
    assert_equal "barbell bench press", press.nombre # aún sin traducir
    assert_equal "pecho", press.musculo
    assert_equal "barbell", press.equipo
    assert_equal "images/0025-AbC1234.jpg", press.imagen_ruta
    assert_equal "videos/0025-AbC1234.gif", press.gif_ruta
    assert_equal 3, press.instrucciones.size # instruction_steps.es
    assert_match "banco plano", press.instrucciones.first

    assert_equal "biceps", Ejercicio.find_by(dataset_id: "0031").musculo
    assert_equal "otro", Ejercicio.find_by(dataset_id: "1160").musculo
  end

  test "sin instruction_steps parte el texto corrido en oraciones" do
    Ejercicios::ImportadorDataset.importar(MUESTRA)

    curl = Ejercicio.find_by(dataset_id: "0031")
    assert_equal 2, curl.instrucciones.size
    assert_match "agarre supino", curl.instrucciones.first
  end

  test "es idempotente y no pisa un nombre ya traducido" do
    Ejercicios::ImportadorDataset.importar(MUESTRA)
    Ejercicio.find_by(dataset_id: "0025").update!(nombre: "Press de banca con barra")

    resumen = Ejercicios::ImportadorDataset.importar(MUESTRA)

    assert_equal 0, resumen[:creados]
    assert_equal 4, resumen[:sin_cambio] + resumen[:actualizados]
    assert_equal "Press de banca con barra", Ejercicio.find_by(dataset_id: "0025").nombre
    assert_equal 4, Ejercicio.count
  end
end
