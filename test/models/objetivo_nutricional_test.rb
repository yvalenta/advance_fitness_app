require "test_helper"

class ObjetivoNutricionalTest < ActiveSupport::TestCase
  test "fijar_para calcula el snapshot con los services" do
    objetivo = ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)

    assert objetivo.persisted?
    assert_equal 2638, objetivo.tdee_kcal   # Mifflin-St Jeor H, 70kg/175cm/30a × 1.6
    assert_equal 2138, objetivo.objetivo_kcal
    assert objetivo.activo?
  end

  test "fijar un objetivo nuevo desactiva el anterior" do
    anterior = ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)
    nuevo = ObjetivoNutricional.fijar_para(users(:one), tipo: "superavit", peso_kg: 71)

    assert nuevo.persisted?
    assert_not anterior.reload.activo?
    assert_equal nuevo, users(:one).objetivo_activo
  end

  test "sin perfil completo no se puede fijar objetivo" do
    objetivo = ObjetivoNutricional.fijar_para(users(:two), tipo: "deficit", peso_kg: 70)

    assert_not objetivo.persisted?
    assert_match(/Completa tu perfil/, objetivo.errors.full_messages.to_sentence)
  end

  test "tipo inválido no se guarda y conserva el objetivo activo anterior" do
    anterior = ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)
    invalido = ObjetivoNutricional.fijar_para(users(:one), tipo: "keto", peso_kg: 70)

    assert_not invalido.persisted?
    assert anterior.reload.activo?
  end

  test "kcal_restantes resta el consumo del objetivo" do
    objetivo = ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)

    assert_equal 938, objetivo.kcal_restantes(1200)
    assert_equal(-62, objetivo.kcal_restantes(2200))
  end
end
