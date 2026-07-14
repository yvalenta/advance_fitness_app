require "rails_helper"

RSpec.describe "PlanesPersonalizados", type: :request do
  # Fase 5.11: con membresía activa y sin objetivo, Mi plan pregunta la meta.
  it "miembro con membresía activa sin objetivo ve el prompt de meta" do
    sign_in_as users(:one)

    get mi_plan_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("¿Cuál es tu meta?")
    expect(users(:one).plan_aprobado).to be_nil
  end

  # Fase 5.11: con objetivo, el plan sugerido se crea (on-demand) y es editable
  # por su dueño, con seguimiento inline en la rutina.
  it "con objetivo se crea el plan sugerido editable con seguimiento inline" do
    ObjetivoNutricional.fijar_para(users(:one), tipo: "superavit", peso_kg: 70)
    sign_in_as users(:one)

    get mi_plan_path

    expect(response).to have_http_status(:success)
    plan = users(:one).plan_aprobado
    expect(plan.reglas?).to be_truthy
    expect(plan.dias.size).to eq(6)
    expect(response.body).to include("Incluido con tu membresía")
    assert_select "input[name=?]", "ejercicio[nombre]"             # editor inline
    expect(response.body).to include("seguimiento#marcar")          # check por ejercicio
    expect(response.body).to include("seguimiento#novedad")         # novedad del día
  end

  it "volver a abrir Mi plan no duplica el plan sugerido" do
    ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)
    sign_in_as users(:one)

    get mi_plan_path
    expect {
      get mi_plan_path
    }.not_to change(PlanPersonalizado, :count)
  end

  # El punto de notificación de borradores aparece para el staff (Fase 5.11)
  it "el staff ve el punto de borradores cuando hay pendientes" do
    PlanPersonalizado.create!(user: users(:one), generado_por: "ia",
                              estado: "generando", rutina: {}, plan_nutricional: {})
    sign_in_as users(:entrenador)

    get root_path
    assert_select "#punto_borradores span.bg-error"
  end

  it "sin pendientes el punto no se muestra" do
    sign_in_as users(:entrenador)
    get root_path
    assert_select "#punto_borradores span.bg-error", count: 0
  end
end
