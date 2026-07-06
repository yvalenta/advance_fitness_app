require "test_helper"

class PlanPersonalizadoTest < ActiveSupport::TestCase
  RUTINA = { "dias" => [ { "dia" => "lunes", "ejercicios" => [] } ] }.freeze
  NUTRICION = { "kcal_diarias" => 2100, "comidas" => [] }.freeze

  test "aprobar! publica el plan con el entrenador que lo revisó" do
    plan = PlanPersonalizado.create!(user: users(:one), rutina: RUTINA, plan_nutricional: NUTRICION)
    plan.aprobar!(users(:entrenador))

    assert plan.aprobado?
    assert_equal users(:entrenador), plan.aprobado_por
  end

  test "aprobar! permite ajustar el JSONB antes de publicar" do
    plan = PlanPersonalizado.create!(user: users(:one), rutina: RUTINA, plan_nutricional: NUTRICION)
    ajustada = { "dias" => [ { "dia" => "martes", "ejercicios" => [] } ] }

    plan.aprobar!(users(:entrenador), rutina: ajustada)

    assert_equal ajustada, plan.reload.rutina
    assert_equal NUTRICION, plan.plan_nutricional
  end

  test "no puede estar aprobado sin aprobador" do
    plan = PlanPersonalizado.new(user: users(:one), rutina: RUTINA,
                                 plan_nutricional: NUTRICION, estado: "aprobado")
    assert_not plan.valid?
  end
end
