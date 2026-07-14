require "rails_helper"

RSpec.describe "GestionPlanes", type: :request do
  rutina = { "dias" => [ { "dia" => "lunes", "enfoque" => "pecho",
                           "ejercicios" => [ { "nombre" => "Press banca", "series" => 4,
                                               "repeticiones" => "8-10", "descanso_seg" => 90 } ] } ] }.freeze
  nutricion = { "kcal_diarias" => 450, "comidas" => [ { "nombre" => "Desayuno", "descripcion" => "Huevos con arepa",
                 "kcal" => 450, "proteinas_g" => 30, "carbohidratos_g" => 40, "grasas_g" => 15 } ] }.freeze

  before do
    @plan = PlanPersonalizado.create!(user: users(:one), rutina: rutina, plan_nutricional: nutricion)
  end

  it "el editor muestra la comida editable y el historial" do
    sign_in_as users(:entrenador)
    get plan_personalizado_path(@plan)

    expect(response).to have_http_status(:success)
    assert_select "input[name='comida[nombre]'][value=Desayuno]"
    assert_select "textarea[name='comida[descripcion]']", text: /Huevos con arepa/
    expect(response.body).to include("Historial del miembro")
    # Editor de rutina (Fase 5.7b): ejercicio editable + enfoque + modal
    assert_select "input[name='ejercicio[nombre]'][value=?]", "Press banca"
    assert_select "input[name='dia[enfoque]']"
    assert_select "dialog[data-modal-ejercicios-target=dialogo]"
    # Fase 5.16: cierre de fondo manual (evita fuga de click al navbar)
    assert_select "dialog[data-action*=cerrarEnBackdrop]"
    assert_select "form[method=dialog]", count: 0
  end

  it "el admin también puede abrir el editor" do
    sign_in_as users(:admin)
    get plan_personalizado_path(@plan)
    expect(response).to have_http_status(:success)
  end

  it "un miembro no puede abrir el editor de un plan" do
    sign_in_as users(:one)
    get plan_personalizado_path(@plan)
    expect(response).to redirect_to(root_path)
  end

  it "el staff reintenta la generación: pone generando y reencola" do
    fallido = PlanPersonalizado.create!(user: users(:one), generado_por: "ia",
                                        estado: "fallido", rutina: {}, plan_nutricional: {})
    sign_in_as users(:entrenador)

    expect {
      post regenerar_plan_personalizado_path(fallido)
    }.to have_enqueued_job(GenerarPlanJob).with(fallido.id)
    expect(fallido.reload.generando?).to be_truthy
  end

  it "un miembro no puede reintentar la generación" do
    sign_in_as users(:one)
    post regenerar_plan_personalizado_path(@plan)
    expect(response).to redirect_to(root_path)
  end

  # Criterio de aceptación F5 (SDD §11): el miembro ve el plan SOLO tras publicar.
  it "el miembro ve su plan solo después de publicar" do
    Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)

    sign_in_as users(:one)
    get mi_plan_path
    expect(response.body).not_to include("Press banca")
    expect(response.body).to include("en preparación")

    sign_in_as users(:entrenador)
    post publicar_plan_personalizado_path(@plan)
    expect(@plan.reload.estado).to eq("aprobado")
    expect(@plan.aprobado_por).to eq(users(:entrenador))

    sign_in_as users(:one)
    get mi_plan_path
    expect(response.body).to include("Press banca")
    expect(response.body).to include("Huevos con arepa")
    # Fase 5.8: suscripción Turbo en vivo, rutina rediseñada (chips) y edición
    # del consumo por el miembro (kcal ajustable + nota + detalle oculto).
    assert_select "turbo-cable-stream-source"
    expect(response.body).to include("4 × 8-10")
    expect(response.body).to include("Enfoque:")
    assert_select "input[data-plan-nutricional-target=kcal]"
    assert_select "input[data-plan-nutricional-target=nota]"
    assert_select "input[name=?]", "registro_caloria[detalle]"
    # Fase 5.11: seguimiento inline (check por ejercicio + novedad del día)
    expect(response.body).to include("seguimiento#marcar")
    expect(response.body).to include("seguimiento#novedad")
    # Fase 5.14: copy sin menciones a "IA" de cara al miembro
    expect(response.body).to include("Analizado y diseñado según tu perfil")
    expect(response.body).not_to match(/\bIA\b/)
    # Fase 6.3: tap en el ejercicio abre el popup de ayuda (dialog + frame perezoso)
    assert_select "button[data-ayuda-url=?]", ayuda_ejercicios_path(nombre: "Press banca")
    assert_select "dialog[data-ayuda-ejercicio-target=dialogo]"
    assert_select "turbo-frame#ayuda_ejercicio"
  end

  it "el modo avanzado guarda el JSON de la rutina" do
    sign_in_as users(:entrenador)
    ajustada = rutina.deep_dup
    ajustada["dias"][0]["ejercicios"][0]["series"] = 5

    patch plan_personalizado_path(@plan), params: { rutina: ajustada.to_json }

    expect(@plan.reload.rutina.dig("dias", 0, "ejercicios", 0, "series")).to eq(5)
    expect(response).to redirect_to(plan_personalizado_path(@plan))
  end

  it "JSON inválido en modo avanzado avisa y no rompe" do
    sign_in_as users(:entrenador)
    patch plan_personalizado_path(@plan), params: { rutina: "{rota" }

    expect(flash[:alert]).to match(/no es válido/)
  end
end
