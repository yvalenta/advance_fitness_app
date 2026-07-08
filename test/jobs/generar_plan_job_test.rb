require "test_helper"

class GenerarPlanJobTest < ActiveJob::TestCase
  RESULTADO = {
    rutina: { "dias" => [ { "dia" => "lunes", "ejercicios" => [] } ] },
    plan_nutricional: { "kcal_diarias" => 2100, "comidas" => [] },
    modelo: "gemini-test"
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

  def plan_generando
    @user.planes_personalizados.create!(estado: "generando", generado_por: "ia",
                                        rutina: {}, plan_nutricional: {})
  end

  test "completa el plan de un miembro premium (borrador + modelo)" do
    Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    plan = plan_generando

    con_ia_stub(RESULTADO) { GenerarPlanJob.perform_now(plan.id) }

    plan.reload
    assert plan.borrador?
    assert_equal RESULTADO[:rutina], plan.rutina
    assert_equal "gemini-test", plan.modelo_generacion
  end

  test "un fallo de la IA deja el plan en fallido con su mensaje" do
    Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    plan = plan_generando

    con_ia_stub(->(*) { raise "Gemini API 503: overloaded" }) do
      GenerarPlanJob.perform_now(plan.id)
    end

    plan.reload
    assert plan.fallido?
    assert_equal 1, plan.intentos
    assert_match "503", plan.error_generacion
    assert_nil @user.plan_aprobado             # el miembro no ve nada
  end

  test "sin suscripción premium marca fallido y no llama a la IA" do
    plan = plan_generando
    centinela = ->(*) { raise "la IA no debe llamarse sin suscripción" }

    con_ia_stub(centinela) { GenerarPlanJob.perform_now(plan.id) }

    assert plan.reload.fallido?
    assert_match(/suscripción/i, plan.error_generacion)
  end
end
