require "rails_helper"

RSpec.describe "GestionDias", type: :request do
  rutina = { "dias" => [
    { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [
      { "nombre" => "Press banca", "series" => 4, "repeticiones" => "8-10", "descanso_seg" => 90 }
    ] }
  ] }.freeze

  before do
    @plan = PlanPersonalizado.create!(user: users(:one), rutina: rutina,
                                      plan_nutricional: { "kcal_diarias" => 100, "comidas" => [] })
  end

  # Fase 5.11: aplicar una sesión completa por músculo refresca solo ese día
  it "el staff aplica una sesión por músculo y recibe el turbo_stream del día" do
    sign_in_as users(:entrenador)

    patch plan_personalizado_dia_path(@plan, 0), as: :json,
          params: { dia: { sesion_musculo: "pierna" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:success)
    expect(response.body).to match("turbo-stream")
    expect(response.body).to match("dia_editor_0")

    dia = @plan.reload.dias[0]
    expect(dia["enfoque"]).to eq("Pierna")
    expect(dia["ejercicios"].map { |e| e["nombre"] }).to include("Sentadilla con barra")
  end

  it "una sesión de un músculo sin plantillas responde 404 y no toca el plan" do
    sign_in_as users(:entrenador)

    patch plan_personalizado_dia_path(@plan, 0), as: :json, params: { dia: { sesion_musculo: "gluteo" } }

    expect(response).to have_http_status(:not_found)
    expect(@plan.reload.dias[0]["enfoque"]).to eq("pecho")
  end

  # Fase 5.11: el dueño de un plan sugerido (reglas) también puede editarlo
  it "el miembro dueño de un plan reglas edita el enfoque y aplica sesiones" do
    plan = PlanPersonalizado.create!(user: users(:one), generado_por: "reglas",
                                     estado: "aprobado", rutina: rutina, plan_nutricional: {})
    sign_in_as users(:one)

    patch plan_personalizado_dia_path(plan, 0), as: :json, params: { dia: { enfoque: "Pecho fuerte" } }
    expect(response).to have_http_status(:success)
    expect(plan.reload.dias[0]["enfoque"]).to eq("Pecho fuerte")
  end

  it "el miembro NO edita su plan de IA aún en borrador (sin publicar)" do
    sign_in_as users(:one)

    # @plan es "borrador" por defecto: aún no visible/editable para el miembro
    patch plan_personalizado_dia_path(@plan, 0), as: :json, params: { dia: { enfoque: "hackeo" } }
    expect(response).to have_http_status(:redirect)
    expect(@plan.reload.dias[0]["enfoque"]).to eq("pecho")
  end

  it "el miembro NO edita el plan (ni reglas ni IA) aprobado de otro" do
    sign_in_as users(:one)

    ajeno_reglas = PlanPersonalizado.create!(user: users(:two), generado_por: "reglas",
                                             estado: "aprobado", rutina: rutina, plan_nutricional: {})
    patch plan_personalizado_dia_path(ajeno_reglas, 0), as: :json, params: { dia: { enfoque: "hackeo" } }
    expect(response).to have_http_status(:redirect)

    ajeno_ia = PlanPersonalizado.create!(user: users(:two), generado_por: "ia", estado: "aprobado",
                                         aprobado_por: users(:entrenador), rutina: rutina,
                                         plan_nutricional: { "kcal_diarias" => 0, "comidas" => [] })
    patch plan_personalizado_dia_path(ajeno_ia, 0), as: :json, params: { dia: { enfoque: "hackeo" } }
    expect(response).to have_http_status(:redirect)
  end

  # Fase 5.12: la rutina de un plan de IA (una vez publicado) también es
  # editable por su dueño; solo la nutrición sigue siendo del staff.
  it "el miembro edita la rutina de su plan de IA ya publicado" do
    plan = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "aprobado",
                                     aprobado_por: users(:entrenador), rutina: rutina,
                                     plan_nutricional: { "kcal_diarias" => 0, "comidas" => [] })
    sign_in_as users(:one)

    patch plan_personalizado_dia_path(plan, 0), as: :json, params: { dia: { enfoque: "Pecho fuerte" } }
    expect(response).to have_http_status(:success)
    expect(plan.reload.dias[0]["enfoque"]).to eq("Pecho fuerte")
  end
end
