require "rails_helper"

RSpec.describe RegistroEntrenamiento, type: :model do
  it "marcar! guarda estado por índice y preserva otros ejercicios" do
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)

    registro.marcar!(0, hecho: true, nota: " subí peso ", nombre: "Press banca")
    registro.marcar!(2, hecho: false, nota: "", nombre: "Sentadilla")

    expect(registro.reload.estado_de(0)["hecho"]).to eq(true)
    expect(registro.estado_de(0)["nota"]).to eq("subí peso")     # strip
    expect(registro.estado_de(0)["nombre"]).to eq("Press banca")
    expect(registro.estado_de(2)["hecho"]).to eq(false)
  end

  it "marcar! sobre el mismo índice reemplaza su estado" do
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    registro.marcar!(0, hecho: true, nota: "a", nombre: "Press")
    registro.marcar!(0, hecho: false, nota: "b", nombre: "Press")

    expect(registro.reload.estado_de(0)["hecho"]).to eq(false)
    expect(registro.estado_de(0)["nota"]).to eq("b")
  end

  it "estado_de de un índice sin marcar es vacío" do
    registro = users(:one).registros_entrenamiento.new(fecha: Date.current)
    expect(registro.estado_de(5)).to eq({})
  end

  it "la novedad del día convive con los checks (Fase 5.11)" do
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    registro.marcar!(0, hecho: true, nombre: "Press")
    registro.marcar_novedad!("  rodilla resentida  ")

    expect(registro.reload.novedad).to eq("rodilla resentida")
    expect(registro.estado_de(0)["hecho"]).to eq(true)
  end

  it "una fila por usuario y fecha" do
    users(:one).registros_entrenamiento.create!(fecha: Date.current)
    repetido = users(:one).registros_entrenamiento.new(fecha: Date.current)

    expect(repetido.valid?).to be_falsey
    expect(repetido.errors[:fecha].any?).to be_truthy
  end
end
