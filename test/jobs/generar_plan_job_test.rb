require "test_helper"

class GenerarPlanJobTest < ActiveJob::TestCase
  RESULTADO = {
    rutina: { "dias" => [ { "dia" => "lunes", "ejercicios" => [] } ] },
    plan_nutricional: { "kcal_diarias" => 2100, "comidas" => [] }
  }.freeze

  setup do
    @user = users(:one)
    ObjetivoNutricional.fijar_para(@user, tipo: "deficit", peso_kg: 70)
  end

  # Reemplaza GeneradorPlanIa.generar durante el bloque (sin red en tests)
  def con_ia_stub(respuesta)
    original = GeneradorPlanIa.method(:generar)
    GeneradorPlanIa.define_singleton_method(:generar) do |*args|
      respuesta.respond_to?(:call) ? respuesta.call(*args) : respuesta
    end
    yield
  ensure
    GeneradorPlanIa.define_singleton_method(:generar, original)
  end

  test "genera el borrador para un miembro premium" do
    Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)

    con_ia_stub(RESULTADO) do
      assert_difference "PlanPersonalizado.count", 1 do
        GenerarPlanJob.perform_now(@user.id)
      end
    end

    plan = @user.planes_personalizados.last
    assert plan.borrador?
    assert_equal "ia", plan.generado_por
    assert_equal RESULTADO[:rutina], plan.rutina
  end

  test "rechaza usuarios sin suscripción premium activa (no llama a la IA)" do
    centinela = ->(*) { raise "la IA no debe llamarse sin suscripción" }

    con_ia_stub(centinela) do
      assert_no_difference "PlanPersonalizado.count" do
        GenerarPlanJob.perform_now(@user.id)
      end
    end
  end

  test "suscripción cancelada tampoco genera" do
    Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "cancelada", fecha_inicio: Date.current)

    assert_no_difference "PlanPersonalizado.count" do
      GenerarPlanJob.perform_now(@user.id)
    end
  end

  test "no duplica si ya hay un borrador en revisión" do
    Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    PlanPersonalizado.create!(user: @user, rutina: RESULTADO[:rutina],
                              plan_nutricional: RESULTADO[:plan_nutricional], generado_por: "ia")

    assert_no_difference "PlanPersonalizado.count" do
      GenerarPlanJob.perform_now(@user.id)
    end
  end
end
