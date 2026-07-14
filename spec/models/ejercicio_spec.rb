require "rails_helper"

RSpec.describe Ejercicio, type: :model do
  def ejercicio_valido(atributos = {})
    Ejercicio.new({ dataset_id: "9999", nombre: "Press de banca", nombre_en: "bench press",
                    musculo: "pecho", categoria: "chest" }.merge(atributos))
  end

  it "calcula el nombre normalizado sin acentos ni mayúsculas" do
    ejercicio = ejercicio_valido(nombre: "  Curl de Bíceps con Barra ")
    expect(ejercicio.valid?).to be_truthy
    expect(ejercicio.nombre_normalizado).to eq("curl de biceps con barra")
  end

  it "dataset_id es único y el músculo debe ser del enum" do
    ejercicio_valido.save!
    duplicado = ejercicio_valido
    expect(duplicado.valid?).to be_falsey

    expect(ejercicio_valido(dataset_id: "9998", musculo: "cuello").valid?).to be_falsey
  end

  it "mapea body_part y target al músculo del dominio" do
    expect(Ejercicio.musculo_desde("chest", "pectorals")).to eq("pecho")
    expect(Ejercicio.musculo_desde("back", "lats")).to eq("espalda")
    expect(Ejercicio.musculo_desde("upper arms", "biceps")).to eq("biceps")
    expect(Ejercicio.musculo_desde("upper arms", "triceps")).to eq("triceps")
    expect(Ejercicio.musculo_desde("upper legs", "glutes")).to eq("gluteo")
    expect(Ejercicio.musculo_desde("upper legs", "quads")).to eq("pierna")
    expect(Ejercicio.musculo_desde("waist", "abs")).to eq("core")
    expect(Ejercicio.musculo_desde("cardio", "cardiovascular system")).to eq("otro")
  end

  it "buscar_por_nombre ignora acentos y cae al nombre en inglés" do
    ejercicio = ejercicio_valido(nombre: "Press de banca con barra")
    ejercicio.save!

    expect(Ejercicio.buscar_por_nombre("press de BANCA con barra")).to eq(ejercicio)
    expect(Ejercicio.buscar_por_nombre("Bench Press")).to eq(ejercicio)
    expect(Ejercicio.buscar_por_nombre("sentadilla búlgara")).to be_nil
    expect(Ejercicio.buscar_por_nombre("")).to be_nil
  end

  it "el scope fuerza excluye cardio y cuello" do
    fuerza = ejercicio_valido
    fuerza.save!
    ejercicio_valido(dataset_id: "9998", categoria: "cardio", musculo: "otro").save!

    expect(Ejercicio.fuerza).to include(fuerza)
    expect(Ejercicio.fuerza.count).to eq(1)
  end
end
