require "rails_helper"

RSpec.describe RegistroEntrenamientoPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:registro_propio) { RegistroEntrenamiento.create!(user: dueno, fecha: Date.current) }

  it "create?: solo el dueño del registro" do
    expect(RegistroEntrenamientoPolicy.new(dueno, registro_propio).create?).to be true
    expect(RegistroEntrenamientoPolicy.new(otro, registro_propio).create?).to be false
  end
end
