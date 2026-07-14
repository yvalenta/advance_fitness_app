require "rails_helper"

RSpec.describe LiberarPlanesEstancadosJob, type: :job do
  it "marca fallido un plan atascado en generando y no toca uno reciente" do
    estancado = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "generando")
    estancado.update_column(:updated_at, 15.minutes.ago)

    reciente = PlanPersonalizado.create!(user: users(:two), generado_por: "ia", estado: "generando")

    LiberarPlanesEstancadosJob.perform_now

    expect(estancado.reload.fallido?).to be_truthy
    expect(estancado.error_generacion).to match("interrumpió")
    expect(reciente.reload.generando?).to be_truthy
  end

  it "no toca planes en otros estados" do
    borrador = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "borrador",
                                          rutina: { "dias" => [] }, plan_nutricional: { "comidas" => [] })
    borrador.update_column(:updated_at, 1.hour.ago)

    LiberarPlanesEstancadosJob.perform_now

    expect(borrador.reload.borrador?).to be_truthy
  end
end
