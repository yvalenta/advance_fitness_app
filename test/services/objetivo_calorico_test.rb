require "test_helper"

class ObjetivoCaloricoTest < ActiveSupport::TestCase
  test "déficit resta 500 kcal" do
    assert_equal 2056, ObjetivoCalorico.kcal(tdee: 2556, tipo: "deficit")
  end

  test "mantenimiento devuelve el TDEE" do
    assert_equal 2556, ObjetivoCalorico.kcal(tdee: 2556, tipo: "mantenimiento")
  end

  test "superávit según somatotipo" do
    assert_equal 3056, ObjetivoCalorico.kcal(tdee: 2556, tipo: "superavit", somatotipo: "ectomorfo")
    assert_equal 2856, ObjetivoCalorico.kcal(tdee: 2556, tipo: "superavit", somatotipo: "endomorfo")
  end

  test "superávit sin somatotipo usa el punto medio" do
    assert_equal 2956, ObjetivoCalorico.kcal(tdee: 2556, tipo: "superavit")
  end
end
