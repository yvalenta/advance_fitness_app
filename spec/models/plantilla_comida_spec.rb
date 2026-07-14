require "rails_helper"

RSpec.describe PlantillaComida, type: :model do
  it "valida tipo, contenido y kcal positivas" do
    plantilla = PlantillaComida.new(tipo: "brunch", nombre: "", descripcion: "", kcal: 0)

    expect(plantilla.valid?).to be_falsey
    expect(plantilla.errors[:tipo].any?).to be_truthy
    expect(plantilla.errors[:nombre].any?).to be_truthy
    expect(plantilla.errors[:descripcion].any?).to be_truthy
    expect(plantilla.errors[:kcal].any?).to be_truthy
  end

  it "el nombre es único dentro del tipo pero se repite entre tipos" do
    existente = plantillas_comida(:desayuno_avena)

    duplicada = PlantillaComida.new(tipo: existente.tipo, nombre: existente.nombre,
                                    descripcion: "otra", kcal: 300)
    expect(duplicada.valid?).to be_falsey

    otro_tipo = PlantillaComida.new(tipo: "snack", nombre: existente.nombre,
                                    descripcion: "otra", kcal: 300)
    expect(otro_tipo.valid?).to be_truthy
  end

  it "tipo_para clasifica los nombres de comidas del plan" do
    expect(PlantillaComida.tipo_para("Desayuno")).to eq("desayuno")
    expect(PlantillaComida.tipo_para("Almuerzo")).to eq("almuerzo")
    expect(PlantillaComida.tipo_para("Cena")).to eq("cena")
    expect(PlantillaComida.tipo_para("Antes de Dormir (Opcional)")).to eq("cena")
    expect(PlantillaComida.tipo_para("Media Mañana")).to eq("snack")
    expect(PlantillaComida.tipo_para("Merienda")).to eq("snack")
  end
end
