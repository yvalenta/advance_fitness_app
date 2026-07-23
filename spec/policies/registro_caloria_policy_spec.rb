require "rails_helper"

RSpec.describe RegistroCaloriaPolicy, type: :model do
  it "create?: cualquier autenticado (el controller lo asocia a Current.user)" do
    expect(RegistroCaloriaPolicy.new(users(:one), RegistroCaloria).create?).to be true
    expect(RegistroCaloriaPolicy.new(nil, RegistroCaloria).create?).to be_falsey
  end
end
