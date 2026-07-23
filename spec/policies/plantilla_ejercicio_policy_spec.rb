require "rails_helper"

RSpec.describe PlantillaEjercicioPolicy, type: :model do
  let(:plantilla) do
    PlantillaEjercicio.first || PlantillaEjercicio.create!(nombre: "P", musculo: "pierna",
                                                           repeticiones: "10-12")
  end

  it "create?/destroy?: solo staff" do
    expect(PlantillaEjercicioPolicy.new(users(:one), plantilla).create?).to be false
    expect(PlantillaEjercicioPolicy.new(users(:entrenador), plantilla).create?).to be true
    expect(PlantillaEjercicioPolicy.new(users(:admin), plantilla).destroy?).to be true
  end
end
