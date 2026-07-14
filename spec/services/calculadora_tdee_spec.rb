require "rails_helper"

RSpec.describe CalculadoraTdee, type: :model do
  it "TMB Mifflin-St Jeor para hombre" do
    # 10·70 + 6.25·175 − 5·30 + 5 = 1648.75
    expect(CalculadoraTdee.tmb(peso_kg: 70, talla_cm: 175, edad: 30, sexo: "M")).to be_within(0.01).of(1648.75)
  end

  it "TMB Mifflin-St Jeor para mujer" do
    # 10·60 + 6.25·165 − 5·25 − 161 = 1345.25
    expect(CalculadoraTdee.tmb(peso_kg: 60, talla_cm: 165, edad: 25, sexo: "F")).to be_within(0.01).of(1345.25)
  end

  it "TDEE aplica el factor de actividad y redondea" do
    # 1648.75 × 1.55 = 2555.56 → 2556
    expect(CalculadoraTdee.tdee(peso_kg: 70, talla_cm: 175, edad: 30, sexo: "M", nivel_actividad: 1.55)).to eq(2556)
  end
end
