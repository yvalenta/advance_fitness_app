require "rails_helper"

# Fase 14.9: cada semana del mesociclo se sirve perezosa en su turbo-frame.
# La capa de modelo real es de 14.7 — aquí se stubea su CONTRATO
# (stubear_mesociclo) para no acoplarse al esquema jsonb interno.
RSpec.describe "GestionSemanas", type: :request do
  rutina = { "dias" => [
    { "dia" => "lunes", "enfoque" => "Pecho", "ejercicios" => [
      { "nombre" => "Press banca", "series" => 4, "repeticiones" => "8-10", "descanso_seg" => 90 }
    ] },
    { "dia" => "martes", "enfoque" => "Pierna", "ejercicios" => [
      { "nombre" => "Sentadilla", "series" => 4, "repeticiones" => "10", "descanso_seg" => 90 }
    ] }
  ] }.freeze

  before do
    @plan = PlanPersonalizado.create!(user: users(:one), generado_por: "reglas",
                                      estado: "aprobado", rutina: rutina, plan_nutricional: {})
  end

  it "el miembro dueño carga una semana en su turbo-frame con los días resueltos" do
    stubear_mesociclo(total: 4, actual: 2)
    sign_in_as users(:one)

    get plan_personalizado_semana_path(@plan, 3)

    expect(response).to have_http_status(:success)
    assert_select "turbo-frame#plan_#{@plan.id}_semana_3"
    expect(response.body).to include("dia_editor_3_0")
    expect(response.body).to include("dia_editor_3_1")
    # Chips de día interactivos: SON los tabs, dentro del subárbol de la semana
    expect(response.body).to include('data-tabs-target="tab"')
  end

  it "el seguimiento de la semana usa las fechas de ESA semana (Rutina::Calendario)" do
    stubear_mesociclo(total: 4, actual: 2)
    sign_in_as users(:one)

    get plan_personalizado_semana_path(@plan, 3)

    # actual = 2 anclada al lunes de esta semana → la semana 3 es el lunes próximo
    lunes_proximo = Date.current.beginning_of_week + 1.week
    assert_select "#dia_editor_3_0[data-fecha='#{lunes_proximo.iso8601}']"
    assert_select "#dia_editor_3_1[data-fecha='#{(lunes_proximo + 1).iso8601}']"
  end

  it "otro miembro NO carga las semanas de un plan ajeno (policy show?)" do
    stubear_mesociclo(total: 4, actual: 1)
    sign_in_as users(:two)

    get plan_personalizado_semana_path(@plan, 2)

    expect(response).to have_http_status(:redirect)
  end

  it "el dueño tampoco ve semanas de su plan aún sin publicar" do
    borrador = PlanPersonalizado.create!(user: users(:one), rutina: rutina,
                                         plan_nutricional: { "kcal_diarias" => 100, "comidas" => [] })
    sign_in_as users(:one)

    get plan_personalizado_semana_path(borrador, 1)

    expect(response).to have_http_status(:redirect)
  end

  it "el staff carga cualquier semana de cualquier plan" do
    stubear_mesociclo(total: 4, actual: 1)
    sign_in_as users(:entrenador)

    get plan_personalizado_semana_path(@plan, 4)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("dia_editor_4_0")
  end

  it "una semana fuera de rango responde 404" do
    stubear_mesociclo(total: 4, actual: 1)
    sign_in_as users(:one)

    get plan_personalizado_semana_path(@plan, 9)
    expect(response).to have_http_status(:not_found)

    get plan_personalizado_semana_path(@plan, 0)
    expect(response).to have_http_status(:not_found)
  end

  it "un plan v1 solo tiene la semana 1 y conserva las tabs clásicas por día" do
    sign_in_as users(:one)

    get plan_personalizado_semana_path(@plan, 1)
    expect(response).to have_http_status(:success)
    expect(response.body).to include("tabs tabs-box")
    expect(response.body).to include("dia_editor_1_0")

    get plan_personalizado_semana_path(@plan, 2)
    expect(response).to have_http_status(:not_found)
  end
end
