require "test_helper"

class LiberarPlanesEstancadosJobTest < ActiveJob::TestCase
  test "marca fallido un plan atascado en generando y no toca uno reciente" do
    estancado = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "generando")
    estancado.update_column(:updated_at, 15.minutes.ago)

    reciente = PlanPersonalizado.create!(user: users(:two), generado_por: "ia", estado: "generando")

    LiberarPlanesEstancadosJob.perform_now

    assert estancado.reload.fallido?
    assert_match "interrumpió", estancado.error_generacion
    assert reciente.reload.generando?
  end

  test "no toca planes en otros estados" do
    borrador = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "borrador",
                                          rutina: { "dias" => [] }, plan_nutricional: { "comidas" => [] })
    borrador.update_column(:updated_at, 1.hour.ago)

    LiberarPlanesEstancadosJob.perform_now

    assert borrador.reload.borrador?
  end
end
