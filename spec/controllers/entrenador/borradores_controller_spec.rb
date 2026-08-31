require "rails_helper"

RSpec.describe "Entrenador::Borradores", type: :request do
  rutina = { "dias" => [ { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [] } ] }.freeze
  nutricion = { "kcal_diarias" => 450, "comidas" => [ { "nombre" => "Desayuno", "descripcion" => "Huevos con arepa",
                 "kcal" => 450, "proteinas_g" => 30, "carbohidratos_g" => 40, "grasas_g" => 15 } ] }.freeze

  before do
    @plan = PlanPersonalizado.create!(user: users(:one), rutina: rutina, plan_nutricional: nutricion)
  end

  it "un miembro no accede a la cola de borradores" do
    sign_in_as users(:one)
    get entrenador_borradores_path
    expect(response).to redirect_to(root_path)
  end

  it "el entrenador ve la cola de revisión con enlace al editor" do
    sign_in_as users(:entrenador)
    get entrenador_borradores_path

    expect(response).to have_http_status(:success)
    expect(response.body).to match("Usuario Uno")
    assert_select "a[href=?]", plan_personalizado_path(@plan)
    # Fase 5.14: sin "generado por ia" crudo ni menciones a IA en el copy
    expect(response.body).to match("Origen: análisis automático")
    expect(response.body).not_to match(/\bIA\b/)
  end

  # Streams por gimnasio (tarea 2026-08-31): la cola se suscribe al par
  # [tenant, "planes_pendientes"] — el mismo al que difunde el modelo. Con el
  # stream global, los turbo streams de un tenant llegaban al staff de todos.
  it "la cola se suscribe al stream de su gimnasio, no al global" do
    sign_in_as users(:entrenador)
    get entrenador_borradores_path

    firmado_af = Turbo::StreamsChannel.signed_stream_name(
      [ tenants(:advance_fitness), "planes_pendientes" ]
    )
    assert_select "turbo-cable-stream-source[signed-stream-name=?]", firmado_af
    assert_select "turbo-cable-stream-source[signed-stream-name=?]",
                  Turbo::StreamsChannel.signed_stream_name("planes_pendientes"), count: 0
  end
end
