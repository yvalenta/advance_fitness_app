require "rails_helper"

# Policy "headless": /progreso solo muestra datos del propio usuario.
RSpec.describe ProgresoPolicy, type: :model do
  it "show?: cualquier autenticado sí, sin usuario no" do
    expect(ProgresoPolicy.new(users(:one), nil).show?).to be true
    expect(ProgresoPolicy.new(nil, nil).show?).to be_falsey
  end
end
