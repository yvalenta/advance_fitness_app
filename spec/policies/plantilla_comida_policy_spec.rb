require "rails_helper"

# Herramienta de staff — el miembro nunca toca plantillas.
RSpec.describe PlantillaComidaPolicy, type: :model do
  it "create?/destroy?: solo staff" do
    plantilla = PlantillaComida.first || PlantillaComida.create!(nombre: "P",
                                          descripcion: "d", tipo: "otros", kcal: 100,
                                          proteinas_g: 10, carbohidratos_g: 10, grasas_g: 5)
    expect(PlantillaComidaPolicy.new(users(:one), plantilla).create?).to be false
    expect(PlantillaComidaPolicy.new(users(:entrenador), plantilla).create?).to be true
    expect(PlantillaComidaPolicy.new(users(:admin), plantilla).destroy?).to be true
  end
end
