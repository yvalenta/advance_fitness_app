require "test_helper"

class Ejercicios::TraductorNombresTest < ActiveSupport::TestCase
  # Proveedor falso con la misma interfaz de Ia::Proveedor* (sin red)
  class ProveedorFalso
    def initialize(respuestas) = @respuestas = respuestas
    def completar(system:, prompt:)
      { texto: @respuestas.shift || "{}", modelo: "falso" }
    end
  end

  def crear_ejercicio(id, nombre_en)
    Ejercicio.create!(dataset_id: id, nombre: nombre_en, nombre_en: nombre_en,
                      musculo: "pecho", categoria: "chest")
  end

  test "traduce solo los pendientes y es reanudable" do
    press = crear_ejercicio("0001", "barbell bench press")
    editado = crear_ejercicio("0002", "dumbbell fly")
    editado.update!(nombre: "Aperturas con mancuernas") # ya traducido a mano

    proveedor = ProveedorFalso.new([ { press.id.to_s => "Press de banca con barra" }.to_json ])
    total = Ejercicios::TraductorNombres.traducir_pendientes(proveedor: proveedor)

    assert_equal 1, total
    assert_equal "Press de banca con barra", press.reload.nombre
    assert_equal "barbell bench press", press.nombre_en          # el original no se toca
    assert_equal "Aperturas con mancuernas", editado.reload.nombre
  end

  test "una respuesta con fences o inservible no cicla infinito" do
    press = crear_ejercicio("0001", "barbell bench press")

    con_fences = ProveedorFalso.new([ "```json\n{\"#{press.id}\": \"Press de banca\"}\n```" ])
    assert_equal 1, Ejercicios::TraductorNombres.traducir_pendientes(proveedor: con_fences)

    crear_ejercicio("0003", "cable pushdown")
    inservible = ProveedorFalso.new([ "no soy json", "{}" ])
    assert_equal 0, Ejercicios::TraductorNombres.traducir_pendientes(proveedor: inservible)
  end
end
