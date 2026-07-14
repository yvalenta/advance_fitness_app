require "rails_helper"

RSpec.describe Ejercicios::TraductorNombres, type: :model do
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

  it "traduce solo los pendientes y es reanudable" do
    press = crear_ejercicio("0001", "barbell bench press")
    editado = crear_ejercicio("0002", "dumbbell fly")
    editado.update!(nombre: "Aperturas con mancuernas") # ya traducido a mano

    proveedor = ProveedorFalso.new([ { press.id.to_s => "Press de banca con barra" }.to_json ])
    total = Ejercicios::TraductorNombres.traducir_pendientes(proveedor: proveedor)

    expect(total).to eq(1)
    expect(press.reload.nombre).to eq("Press de banca con barra")
    expect(press.nombre_en).to eq("barbell bench press")          # el original no se toca
    expect(editado.reload.nombre).to eq("Aperturas con mancuernas")
  end

  it "una respuesta con fences o inservible no cicla infinito" do
    press = crear_ejercicio("0001", "barbell bench press")

    con_fences = ProveedorFalso.new([ "```json\n{\"#{press.id}\": \"Press de banca\"}\n```" ])
    expect(Ejercicios::TraductorNombres.traducir_pendientes(proveedor: con_fences)).to eq(1)

    crear_ejercicio("0003", "cable pushdown")
    inservible = ProveedorFalso.new([ "no soy json", "{}" ])
    expect(Ejercicios::TraductorNombres.traducir_pendientes(proveedor: inservible)).to eq(0)
  end
end
