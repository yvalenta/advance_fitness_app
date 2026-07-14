require "rails_helper"

RSpec.describe ObjetivoCalorico, type: :model do
  it "déficit resta 500 kcal" do
    expect(ObjetivoCalorico.kcal(tdee: 2556, tipo: "deficit")).to eq(2056)
  end

  it "mantenimiento devuelve el TDEE" do
    expect(ObjetivoCalorico.kcal(tdee: 2556, tipo: "mantenimiento")).to eq(2556)
  end

  it "superávit según somatotipo" do
    expect(ObjetivoCalorico.kcal(tdee: 2556, tipo: "superavit", somatotipo: "ectomorfo")).to eq(3056)
    expect(ObjetivoCalorico.kcal(tdee: 2556, tipo: "superavit", somatotipo: "endomorfo")).to eq(2856)
  end

  it "superávit sin somatotipo usa el punto medio" do
    expect(ObjetivoCalorico.kcal(tdee: 2556, tipo: "superavit")).to eq(2956)
  end
end
