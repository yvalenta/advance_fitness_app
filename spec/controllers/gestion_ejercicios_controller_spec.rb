require "rails_helper"

RSpec.describe "GestionEjercicios", type: :request do
  def rutina
    { "dias" => [
      { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [
        { "nombre" => "Press banca", "series" => 4, "repeticiones" => "8-10", "descanso_seg" => 90 }
      ] }
    ] }.freeze
  end

  def nutricion
    { "kcal_diarias" => 100, "comidas" => [] }.freeze
  end

  before do
    @plan = PlanPersonalizado.create!(user: users(:one), rutina: rutina, plan_nutricional: nutricion)
  end

  it "el staff autosalva un ejercicio por día e índice" do
    sign_in_as users(:entrenador)

    patch plan_personalizado_dia_ejercicio_path(@plan, 0, 0), as: :json,
          params: { ejercicio: { nombre: "Press inclinado", series: "5", repeticiones: "6-8", descanso_seg: "120" } }

    expect(response).to have_http_status(:success)
    ej = @plan.reload.ejercicios_de(0).first
    expect(ej["nombre"]).to eq("Press inclinado")
    expect(ej["series"]).to eq(5)
  end

  it "agregar y eliminar ejercicios de un día responde turbo_stream sin recargar" do
    sign_in_as users(:admin)

    expect {
      post plan_personalizado_dia_ejercicios_path(@plan, 0),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }, params: { ejercicio: { nombre: "Aperturas" } }
    }.to change { @plan.reload.ejercicios_de(0).size }.by(1)
    expect(response).to have_http_status(:success)
    expect(response.media_type).to match("turbo-stream")
    assert_select "turbo-stream[action=replace][target=dia_editor_0]"

    expect {
      delete plan_personalizado_dia_ejercicio_path(@plan, 0, 0), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    }.to change { @plan.reload.ejercicios_de(0).size }.by(-1)
    expect(response).to have_http_status(:success)
  end

  it "un índice de ejercicio inexistente responde 404" do
    sign_in_as users(:entrenador)
    patch plan_personalizado_dia_ejercicio_path(@plan, 0, 9), as: :json, params: { ejercicio: { series: "3" } }
    expect(response).to have_http_status(:not_found)
  end

  it "un miembro no puede editar la rutina de un plan sin publicar" do
    sign_in_as users(:one)
    expect {
      patch plan_personalizado_dia_ejercicio_path(@plan, 0, 0), as: :json, params: { ejercicio: { series: "9" } }
    }.not_to change { @plan.reload.ejercicios_de(0).first["series"] }
    expect(response).to have_http_status(:redirect)
  end

  # Fase 5.12: publicado, el dueño edita la rutina aunque sea de IA
  it "el dueño edita un ejercicio de su plan de IA ya publicado" do
    publicado = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "aprobado",
                                          aprobado_por: users(:entrenador), rutina: rutina,
                                          plan_nutricional: { "kcal_diarias" => 0, "comidas" => [] })
    sign_in_as users(:one)

    patch plan_personalizado_dia_ejercicio_path(publicado, 0, 0), as: :json, params: { ejercicio: { series: "9" } }

    expect(response).to have_http_status(:success)
    expect(publicado.reload.ejercicios_de(0).first["series"]).to eq(9)
  end
end
