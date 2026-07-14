require "rails_helper"

RSpec.describe DetalleEntrenamiento, type: :model do
  let(:registro) { RegistroEntrenamiento.create!(user: users(:one), fecha: Date.current) }
  let(:ejercicio) do
    Ejercicio.create!(dataset_id: "test-0001", nombre: "Press de banca", nombre_en: "Bench press",
                      nombre_normalizado: "press de banca", categoria: "fuerza", musculo: "pecho")
  end

  def detalle(atributos = {})
    DetalleEntrenamiento.new({ registro_entrenamiento: registro, ejercicio: ejercicio,
                               serie: 1, repeticiones: 10, peso_kg: 60 }.merge(atributos))
  end

  it "es válido con serie, repeticiones y peso" do
    expect(detalle).to be_valid
  end

  it "acepta peso nulo (peso corporal) y RPE opcional en 1..10" do
    expect(detalle(peso_kg: nil, rpe: 8)).to be_valid
    expect(detalle(rpe: 11)).not_to be_valid
    expect(detalle(rpe: 0)).not_to be_valid
  end

  it "rechaza series o repeticiones menores a 1 y pesos negativos" do
    expect(detalle(serie: 0)).not_to be_valid
    expect(detalle(repeticiones: 0)).not_to be_valid
    expect(detalle(peso_kg: -5)).not_to be_valid
  end

  it "no permite dos filas para la misma serie de un ejercicio en una sesión" do
    detalle.save!
    expect(detalle(peso_kg: 70)).not_to be_valid
    expect(detalle(serie: 2)).to be_valid
  end

  it "calcula el volumen de carga de la serie (peso corporal aporta 0)" do
    expect(detalle.volumen_kg).to eq(600)
    expect(detalle(peso_kg: nil).volumen_kg).to eq(0)
  end

  it "se borra en cascada con el registro de entrenamiento" do
    detalle.save!
    expect { registro.destroy! }.to change(DetalleEntrenamiento, :count).by(-1)
  end

  describe ".ejercicio_para" do
    it "resuelve por id cuando el plan trae ejercicio_id" do
      resultado = DetalleEntrenamiento.ejercicio_para(ejercicio_id: ejercicio.id, nombre: "otro nombre")
      expect(resultado).to eq(ejercicio)
    end

    it "resuelve por nombre normalizado cuando no hay ejercicio_id (planes viejos)" do
      ejercicio # fuerza la creación antes de buscar por nombre
      resultado = DetalleEntrenamiento.ejercicio_para(ejercicio_id: nil, nombre: "Press De Banca")
      expect(resultado).to eq(ejercicio)
    end

    it "devuelve nil sin id ni nombre coincidente" do
      expect(DetalleEntrenamiento.ejercicio_para(ejercicio_id: nil, nombre: "Ejercicio inventado")).to be_nil
    end
  end
end
