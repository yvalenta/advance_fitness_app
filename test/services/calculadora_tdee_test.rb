require "test_helper"

class CalculadoraTdeeTest < ActiveSupport::TestCase
  test "TMB Mifflin-St Jeor para hombre" do
    # 10·70 + 6.25·175 − 5·30 + 5 = 1648.75
    assert_in_delta 1648.75, CalculadoraTdee.tmb(peso_kg: 70, talla_cm: 175, edad: 30, sexo: "M"), 0.01
  end

  test "TMB Mifflin-St Jeor para mujer" do
    # 10·60 + 6.25·165 − 5·25 − 161 = 1345.25
    assert_in_delta 1345.25, CalculadoraTdee.tmb(peso_kg: 60, talla_cm: 165, edad: 25, sexo: "F"), 0.01
  end

  test "TDEE aplica el factor de actividad y redondea" do
    # 1648.75 × 1.55 = 2555.56 → 2556
    assert_equal 2556, CalculadoraTdee.tdee(peso_kg: 70, talla_cm: 175, edad: 30, sexo: "M", nivel_actividad: 1.55)
  end
end
