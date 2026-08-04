require "rails_helper"

# Fase 14.9 — eje de semanas del mesociclo en la rutina de "Mi plan": solo la
# semana activa vive en el DOM inicial, las demás son turbo-frames perezosos.
# El contrato del modelo (14.7) se stubea con stubear_mesociclo.
RSpec.describe "Eje de semanas del mesociclo", type: :request do
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

  it "un plan v1 renderiza su semana única SIN eje de semanas, igual que siempre" do
    sign_in_as users(:one)

    get mi_plan_path

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include('data-mesociclo-target')
    expect(response.body).not_to include("Semana 2")
    expect(response.body).to include("tabs tabs-box")   # tabs clásicas por día
    expect(response.body).to include("dia_editor_1_0")  # panel inline (semana 1)
    expect(response.body).to include("seguimiento#marcar")
  end

  it "con mesociclo, SOLO la semana activa vive en el DOM inicial" do
    stubear_mesociclo(total: 4, actual: 2)
    sign_in_as users(:one)

    get mi_plan_path

    expect(response).to have_http_status(:success)
    # Eje completo: una sección por semana con su progreso
    expect(response.body).to include("Semana 1")
    expect(response.body).to include("Semana 4")
    assert_select "section[data-mesociclo-target=semana]", count: 4

    # Los paneles de día solo existen para la semana activa (2)
    expect(response.body).to include("dia_editor_2_0")
    expect(response.body).not_to include("dia_editor_1_0")
    expect(response.body).not_to include("dia_editor_3_0")
    expect(response.body).not_to include("dia_editor_4_0")

    # Las demás semanas: turbo-frame perezoso oculto servido por GestionSemanas
    assert_select "turbo-frame[loading=lazy][hidden][src*=?]", "semanas", count: 3
    expect(response.body).to include(plan_personalizado_semana_path(@plan, 3))
  end

  it "el eje muestra Descarga y Personalizada, y el seguimiento activo cae en esta semana" do
    stubear_mesociclo(total: 4, actual: 2, descarga: [ 4 ], materializadas: [ 3 ])
    sign_in_as users(:one)

    get mi_plan_path

    expect(response.body).to include("Descarga")
    expect(response.body).to include("Personalizada")
    # La semana activa (2) queda anclada a la semana calendario actual
    assert_select "#dia_editor_2_0[data-fecha='#{Date.current.beginning_of_week.iso8601}']"
  end

  it "la barra de progreso de cada semana sale de los registros de SUS fechas" do
    stubear_mesociclo(total: 3, actual: 2)
    # Semana 1 = semana calendario pasada: un ejercicio hecho el lunes anterior
    users(:one).registros_entrenamiento.create!(
      fecha: Date.current.beginning_of_week - 1.week,
      ejercicios: { "0" => { "hecho" => true, "nombre" => "Press banca" } }
    )
    sign_in_as users(:one)

    get mi_plan_path

    # 2 días × 1 ejercicio = total 2 por semana; solo la semana 1 tiene 1 hecho
    assert_select "section[data-numero='1'][data-hechos='1'][data-total='2']"
    assert_select "section[data-numero='2'][data-hechos='0'][data-total='2']"
    assert_select "section[data-numero='3'][data-hechos='0'][data-total='2']"
  end

  it "en el editor del staff los frames de semana conservan el modo edición (editor=1)" do
    stubear_mesociclo(total: 4, actual: 2)
    sign_in_as users(:entrenador)

    get plan_personalizado_path(@plan)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("editor=1")
  end
end
