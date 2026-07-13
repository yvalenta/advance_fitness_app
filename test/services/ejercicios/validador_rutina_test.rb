require "test_helper"

class Ejercicios::ValidadorRutinaTest < ActiveSupport::TestCase
  setup do
    @press = Ejercicio.create!(dataset_id: "0025", nombre: "Press de banca con barra",
                               nombre_en: "barbell bench press", musculo: "pecho", categoria: "chest")
  end

  def rutina_con(ejercicio)
    { "dias" => [ { "dia" => "lunes", "ejercicios" => [ ejercicio ] } ] }
  end

  test "id válido se conserva y el nombre se pisa con el del catálogo" do
    resultado = Ejercicios::ValidadorRutina.corregir!(
      rutina_con({ "ejercicio_id" => @press.id, "nombre" => "press banca (variante IA)", "series" => 4 })
    )

    ejercicio = resultado[:rutina]["dias"][0]["ejercicios"][0]
    assert_equal @press.id, ejercicio["ejercicio_id"]
    assert_equal "Press de banca con barra", ejercicio["nombre"]
    assert_equal 1, resultado[:correcciones]
  end

  test "id alucinado se rescata por nombre" do
    resultado = Ejercicios::ValidadorRutina.corregir!(
      rutina_con({ "ejercicio_id" => 999_999, "nombre" => "Préss de Banca con Barra" })
    )

    ejercicio = resultado[:rutina]["dias"][0]["ejercicios"][0]
    assert_equal @press.id, ejercicio["ejercicio_id"]
    assert_equal 1, resultado[:correcciones]
  end

  test "sin match se elimina el id pero el ejercicio sobrevive" do
    resultado = Ejercicios::ValidadorRutina.corregir!(
      rutina_con({ "ejercicio_id" => 999_999, "nombre" => "Invento total", "series" => 3 })
    )

    ejercicio = resultado[:rutina]["dias"][0]["ejercicios"][0]
    assert_nil ejercicio["ejercicio_id"]
    assert_equal "Invento total", ejercicio["nombre"]
    assert_equal 1, resultado[:correcciones]
  end

  test "una rutina correcta pasa sin correcciones" do
    resultado = Ejercicios::ValidadorRutina.corregir!(
      rutina_con({ "ejercicio_id" => @press.id, "nombre" => "Press de banca con barra" })
    )

    assert_equal 0, resultado[:correcciones]
  end
end
