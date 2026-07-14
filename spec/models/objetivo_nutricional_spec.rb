require "rails_helper"

RSpec.describe ObjetivoNutricional, type: :model do
  it "fijar_para calcula el snapshot con los services" do
    objetivo = ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)

    expect(objetivo.persisted?).to be_truthy
    expect(objetivo.tdee_kcal).to eq(2638)   # Mifflin-St Jeor H, 70kg/175cm/30a × 1.6
    expect(objetivo.objetivo_kcal).to eq(2138)
    expect(objetivo.activo?).to be_truthy
  end

  it "fijar un objetivo nuevo desactiva el anterior" do
    anterior = ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)
    nuevo = ObjetivoNutricional.fijar_para(users(:one), tipo: "superavit", peso_kg: 71)

    expect(nuevo.persisted?).to be_truthy
    expect(anterior.reload.activo?).to be_falsey
    expect(users(:one).objetivo_activo).to eq(nuevo)
  end

  it "sin perfil completo no se puede fijar objetivo" do
    objetivo = ObjetivoNutricional.fijar_para(users(:two), tipo: "deficit", peso_kg: 70)

    expect(objetivo.persisted?).to be_falsey
    expect(objetivo.errors.full_messages.to_sentence).to match(/Completa tu perfil/)
  end

  it "tipo inválido no se guarda y conserva el objetivo activo anterior" do
    anterior = ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)
    invalido = ObjetivoNutricional.fijar_para(users(:one), tipo: "keto", peso_kg: 70)

    expect(invalido.persisted?).to be_falsey
    expect(anterior.reload.activo?).to be_truthy
  end

  it "kcal_restantes resta el consumo del objetivo" do
    objetivo = ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)

    expect(objetivo.kcal_restantes(1200)).to eq(938)
    expect(objetivo.kcal_restantes(2200)).to eq(-62)
  end
end
