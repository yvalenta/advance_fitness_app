require "rails_helper"

RSpec.describe GenerarPlanJob, type: :job do
  def resultado
    {
      rutina: { "dias" => [ { "dia" => "lunes", "ejercicios" => [] } ] },
      plan_nutricional: { "kcal_diarias" => 2100, "comidas" => [] },
      modelo: "gemini-test"
    }.freeze
  end

  before do
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

  it "completa el plan de un miembro premium (borrador + modelo)" do
    Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    plan = plan_generando

    con_ia_stub(resultado) { GenerarPlanJob.perform_now(plan.id) }

    plan.reload
    expect(plan.borrador?).to be_truthy
    expect(plan.rutina).to eq(resultado[:rutina])
    expect(plan.modelo_generacion).to eq("gemini-test")
  end

  # Fase 6.5: el job pasa la rutina de la IA por el validador de catálogo
  it "un ejercicio_id alucinado se rescata o se limpia antes de completar" do
    press = Ejercicio.create!(dataset_id: "0025", nombre: "Press de banca", nombre_en: "barbell bench press",
                              musculo: "pecho", categoria: "chest")
    Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    plan = plan_generando

    con_alucinacion = resultado.merge(rutina: { "dias" => [ { "dia" => "lunes", "ejercicios" => [
      { "ejercicio_id" => 999_999, "nombre" => "press de banca" },
      { "ejercicio_id" => 888_888, "nombre" => "Invento marciano" }
    ] } ] })

    con_ia_stub(con_alucinacion) { GenerarPlanJob.perform_now(plan.id) }

    ejercicios = plan.reload.rutina["dias"][0]["ejercicios"]
    expect(ejercicios[0]["ejercicio_id"]).to eq(press.id)      # rescatado por nombre
    expect(ejercicios[1]["ejercicio_id"]).to be_nil            # limpiado, sobrevive
    expect(ejercicios[1]["nombre"]).to eq("Invento marciano")
    expect(plan.borrador?).to be_truthy
  end

  # Fase 6.6: la adherencia real viaja en el perfil cuando hay registros
  it "el perfil lleva catálogo y adherencia cuando hay seguimiento" do
    Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    RegistroEntrenamiento.create!(user: @user, fecha: Date.current.beginning_of_week,
                                  ejercicios: { "0" => { "hecho" => true, "nombre" => "Press banca" } })
    plan = plan_generando
    perfil_visto = nil

    con_ia_stub(->(perfil) { perfil_visto = perfil; resultado }) { GenerarPlanJob.perform_now(plan.id) }

    expect(perfil_visto.key?(:catalogo)).to be_truthy
    expect(perfil_visto[:adherencia][:pct_global]).to eq(100)
  end

  # Etapa 14.10: al regenerar, la adherencia lleva la posición en el
  # mesociclo del plan vigente y el desglose por semana del ciclo
  it "la adherencia lleva la posición del ciclo del plan vigente" do
    Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    vigente = PlanPersonalizado.new(
      user: @user, generado_por: "reglas", estado: "aprobado", plan_nutricional: {},
      rutina: { "dias" => [ { "dia" => "lunes", "ejercicios" => [] } ],
                "semanas" => [ { "numero" => 1, "etiqueta" => "Adaptación", "descarga" => false },
                               { "numero" => 2, "etiqueta" => "Acumulación", "descarga" => false },
                               { "numero" => 3, "etiqueta" => "Intensificación", "descarga" => false },
                               { "numero" => 4, "etiqueta" => "Descarga", "descarga" => true } ] })
    vigente.created_at = 2.weeks.ago # su ciclo va en la semana 3 de 4
    vigente.save!
    RegistroEntrenamiento.create!(user: @user, fecha: Date.current.beginning_of_week,
                                  ejercicios: { "0" => { "hecho" => true, "nombre" => "Press banca" } })
    plan = plan_generando
    perfil_visto = nil

    con_ia_stub(->(perfil) { perfil_visto = perfil; resultado }) { GenerarPlanJob.perform_now(plan.id) }

    adherencia = perfil_visto[:adherencia]
    expect(adherencia[:contexto_ciclo])
      .to eq("Va en la semana 3 de 4 (Intensificación); la próxima es descarga.")
    expect(adherencia[:por_semana])
      .to eq([ { numero: 3, etiqueta: "Intensificación", descarga: false,
                 hechos: 1, total: 1, porcentaje: 100 } ])
  end

  it "un fallo de la IA deja el plan en fallido con su mensaje" do
    Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    plan = plan_generando

    con_ia_stub(->(*) { raise "Gemini API 503: overloaded" }) do
      GenerarPlanJob.perform_now(plan.id)
    end

    plan.reload
    expect(plan.fallido?).to be_truthy
    expect(plan.intentos).to eq(1)
    expect(plan.error_generacion).to match("503")
    expect(@user.plan_aprobado).to be_nil             # el miembro no ve nada
  end

  it "sin suscripción premium marca fallido y no llama a la IA" do
    plan = plan_generando
    centinela = ->(*) { raise "la IA no debe llamarse sin suscripción" }

    con_ia_stub(centinela) { GenerarPlanJob.perform_now(plan.id) }

    expect(plan.reload.fallido?).to be_truthy
    expect(plan.error_generacion).to match(/suscripción/i)
  end

  # Fase 14.16: la fase del ciclo viaja al proveedor SOLO con el consentimiento
  # de segundo nivel (ciclo_menstrual_ia). El de registro no basta.
  describe "fase del ciclo en el perfil de la IA" do
    before do
      Suscripcion.create!(user: @user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
      @user.consentimientos.create!(tipo: "ciclo_menstrual", accion: "otorgado", version_texto: "ciclo-v1")
      CicloMenstrual.create!(user: @user, creado_por: @user, fecha_inicio: Date.current)
    end

    it "viaja con el consentimiento de IA vigente" do
      @user.consentimientos.create!(tipo: "ciclo_menstrual_ia", accion: "otorgado", version_texto: "ciclo-ia-v1")
      plan = plan_generando
      perfil_visto = nil

      con_ia_stub(->(perfil) { perfil_visto = perfil; resultado }) { GenerarPlanJob.perform_now(plan.id) }

      expect(perfil_visto[:ciclo]).to eq("menstrual")
    end

    it "NO viaja con solo el consentimiento de registro" do
      plan = plan_generando
      perfil_visto = nil

      con_ia_stub(->(perfil) { perfil_visto = perfil; resultado }) { GenerarPlanJob.perform_now(plan.id) }

      expect(perfil_visto[:ciclo]).to be_nil
    end
  end
end
