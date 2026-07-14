require "rails_helper"

RSpec.describe PlantillaEjercicio, type: :model do
  it "valida músculo, nombre y repeticiones" do
    p = PlantillaEjercicio.new(musculo: "brazo", nombre: "", repeticiones: "")
    expect(p.valid?).to be_falsey
    expect(p.errors[:musculo].any?).to be_truthy
    expect(p.errors[:nombre].any?).to be_truthy
    expect(p.errors[:repeticiones].any?).to be_truthy
  end

  it "el nombre es único por músculo pero se repite entre músculos" do
    base = plantillas_ejercicio(:press_banca)

    dup = PlantillaEjercicio.new(musculo: base.musculo, nombre: base.nombre, repeticiones: "10")
    expect(dup.valid?).to be_falsey

    otro = PlantillaEjercicio.new(musculo: "otro", nombre: base.nombre, repeticiones: "10")
    expect(otro.valid?).to be_truthy
  end
end
