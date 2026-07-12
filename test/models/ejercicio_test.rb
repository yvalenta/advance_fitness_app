require "test_helper"

class EjercicioTest < ActiveSupport::TestCase
  def ejercicio_valido(atributos = {})
    Ejercicio.new({ dataset_id: "9999", nombre: "Press de banca", nombre_en: "bench press",
                    musculo: "pecho", categoria: "chest" }.merge(atributos))
  end

  test "calcula el nombre normalizado sin acentos ni mayúsculas" do
    ejercicio = ejercicio_valido(nombre: "  Curl de Bíceps con Barra ")
    assert ejercicio.valid?
    assert_equal "curl de biceps con barra", ejercicio.nombre_normalizado
  end

  test "dataset_id es único y el músculo debe ser del enum" do
    ejercicio_valido.save!
    duplicado = ejercicio_valido
    assert_not duplicado.valid?

    assert_not ejercicio_valido(dataset_id: "9998", musculo: "cuello").valid?
  end

  test "mapea body_part y target al músculo del dominio" do
    assert_equal "pecho", Ejercicio.musculo_desde("chest", "pectorals")
    assert_equal "espalda", Ejercicio.musculo_desde("back", "lats")
    assert_equal "biceps", Ejercicio.musculo_desde("upper arms", "biceps")
    assert_equal "triceps", Ejercicio.musculo_desde("upper arms", "triceps")
    assert_equal "gluteo", Ejercicio.musculo_desde("upper legs", "glutes")
    assert_equal "pierna", Ejercicio.musculo_desde("upper legs", "quads")
    assert_equal "core", Ejercicio.musculo_desde("waist", "abs")
    assert_equal "otro", Ejercicio.musculo_desde("cardio", "cardiovascular system")
  end

  test "buscar_por_nombre ignora acentos y cae al nombre en inglés" do
    ejercicio = ejercicio_valido(nombre: "Press de banca con barra")
    ejercicio.save!

    assert_equal ejercicio, Ejercicio.buscar_por_nombre("press de BANCA con barra")
    assert_equal ejercicio, Ejercicio.buscar_por_nombre("Bench Press")
    assert_nil Ejercicio.buscar_por_nombre("sentadilla búlgara")
    assert_nil Ejercicio.buscar_por_nombre("")
  end

  test "el scope fuerza excluye cardio y cuello" do
    fuerza = ejercicio_valido
    fuerza.save!
    ejercicio_valido(dataset_id: "9998", categoria: "cardio", musculo: "otro").save!

    assert_includes Ejercicio.fuerza, fuerza
    assert_equal 1, Ejercicio.fuerza.count
  end
end
