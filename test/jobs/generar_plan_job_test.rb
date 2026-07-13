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

  # Fase 6.5: el job pasa la rutina de la IA por el validador de catálogo
  test "un ejercicio_id alucinado se rescata o se limpia antes de completar" do
    press = Ejercicio.create!(dataset_id: "0025", nombre: "Press de banca", nombre_en: "barbell bench press",
                              musculo: "pecho", categoria: "chest")
    Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    plan = plan_generando

    con_alucinacion = RESULTADO.merge(rutina: { "dias" => [ { "dia" => "lunes", "ejercicios" => [
      { "ejercicio_id" => 999_999, "nombre" => "press de banca" },
      { "ejercicio_id" => 888_888, "nombre" => "Invento marciano" }
    ] } ] })

    con_ia_stub(con_alucinacion) { GenerarPlanJob.perform_now(plan.id) }

    ejercicios = plan.reload.rutina["dias"][0]["ejercicios"]
    assert_equal press.id, ejercicios[0]["ejercicio_id"]      # rescatado por nombre
    assert_nil ejercicios[1]["ejercicio_id"]                  # limpiado, sobrevive
    assert_equal "Invento marciano", ejercicios[1]["nombre"]
    assert plan.borrador?
  end

  # Fase 6.6: la adherencia real viaja en el perfil cuando hay registros
  test "el perfil lleva catálogo y adherencia cuando hay seguimiento" do
    Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    RegistroEntrenamiento.create!(user: @user, fecha: Date.current.beginning_of_week,
                                  ejercicios: { "0" => { "hecho" => true, "nombre" => "Press banca" } })
    plan = plan_generando
    perfil_visto = nil

    con_ia_stub(->(perfil) { perfil_visto = perfil; RESULTADO }) { GenerarPlanJob.perform_now(plan.id) }

    assert perfil_visto.key?(:catalogo)
    assert_equal 100, perfil_visto[:adherencia][:pct_global]
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
