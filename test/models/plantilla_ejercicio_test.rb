require "test_helper"

class PlantillaEjercicioTest < ActiveSupport::TestCase
  test "valida músculo, nombre y repeticiones" do
    p = PlantillaEjercicio.new(musculo: "brazo", nombre: "", repeticiones: "")
    assert_not p.valid?
    assert p.errors[:musculo].any?
    assert p.errors[:nombre].any?
    assert p.errors[:repeticiones].any?
  end

  test "el nombre es único por músculo pero se repite entre músculos" do
    base = plantillas_ejercicio(:press_banca)

    dup = PlantillaEjercicio.new(musculo: base.musculo, nombre: base.nombre, repeticiones: "10")
    assert_not dup.valid?

    otro = PlantillaEjercicio.new(musculo: "otro", nombre: base.nombre, repeticiones: "10")
    assert otro.valid?
  end
end
