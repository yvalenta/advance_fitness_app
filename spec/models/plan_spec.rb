require "rails_helper"

RSpec.describe Plan, type: :model do
  # Hotfix 5.11: una base sin seeds no debe romper el alta de suscripciones
  # ("Plan debe existir"): el catálogo se autocrea con precios de Negocio.
  it "Plan.personalizado se autocrea en una base sin seeds" do
    Plan.delete_all

    plan = Plan.personalizado
    expect(plan.persisted?).to be_truthy
    expect(plan.precio.to_i).to eq(Negocio.precio_personalizado)
    expect {
      Plan.personalizado # idempotente
    }.not_to change(Plan, :count)
  end

  it "Plan.free se autocrea con precio cero" do
    Plan.delete_all
    expect(Plan.free.precio.to_i).to eq(0)
  end
end
