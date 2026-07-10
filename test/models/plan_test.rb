require "test_helper"

class PlanTest < ActiveSupport::TestCase
  # Hotfix 5.11: una base sin seeds no debe romper el alta de suscripciones
  # ("Plan debe existir"): el catálogo se autocrea con precios de Negocio.
  test "Plan.personalizado se autocrea en una base sin seeds" do
    Plan.delete_all

    plan = Plan.personalizado
    assert plan.persisted?
    assert_equal Negocio.precio_personalizado, plan.precio.to_i
    assert_no_difference "Plan.count" do
      Plan.personalizado # idempotente
    end
  end

  test "Plan.free se autocrea con precio cero" do
    Plan.delete_all
    assert_equal 0, Plan.free.precio.to_i
  end
end
