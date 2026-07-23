require "rails_helper"

RSpec.describe SuscripcionPolicy, type: :model do
  let(:susc) do
    Suscripcion.create!(user: users(:one), plan: planes(:free), estado: "activa",
                        fecha_inicio: Date.current)
  end

  it "index?/create?/update?: solo admin (SDD §08 flujo B)" do
    expect(SuscripcionPolicy.new(users(:one), susc).index?).to be false
    expect(SuscripcionPolicy.new(users(:entrenador), susc).create?).to be false
    expect(SuscripcionPolicy.new(users(:admin), susc).index?).to be true
    expect(SuscripcionPolicy.new(users(:admin), susc).create?).to be true
    expect(SuscripcionPolicy.new(users(:admin), susc).update?).to be true
  end
end
