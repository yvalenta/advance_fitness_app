require "rails_helper"

# El catálogo de planes es global (Free/Personalizado). Todo autenticado
# lo consulta desde la pantalla de upgrade.
RSpec.describe PlanPolicy, type: :model do
  it "index?: cualquier autenticado sí, sin usuario no" do
    expect(PlanPolicy.new(users(:one), Plan).index?).to be true
    expect(PlanPolicy.new(nil, Plan).index?).to be_falsey
  end
end
