require "rails_helper"

# Modo sesión (Fase 14.3): pantalla inmersiva del entrenamiento del día.
RSpec.describe "Sesiones", type: :request do
  let(:lunes) { Date.current.beginning_of_week }
  let(:rutina) do
    { "dias" => [
      { "dia" => "lunes", "enfoque" => "Empuje: pecho y tríceps",
        "ejercicios" => [
          { "uid" => "abc123", "nombre" => "Press banca", "series" => 3,
            "repeticiones" => "12-15", "descanso_seg" => 90,
            "peso_sugerido_kg" => 60, "nota_tecnica" => "Escápulas retraídas" },
          { "nombre" => "Fondos", "series" => 4, "repeticiones" => "10" }
        ] }
    ] }
  end

  def crear_plan!(user, rutina:)
    PlanPersonalizado.create!(user: user, generado_por: "reglas", estado: "aprobado",
                              rutina: rutina, plan_nutricional: {})
  end

  it "muestra la sesión del día con avance, chips de series y nota técnica" do
    crear_plan!(users(:one), rutina: rutina)
    sign_in_as users(:one)

    get sesion_path(lunes.iso8601)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Ejercicio 1 de 2")
    expect(response.body).to include("Press banca")
    expect(response.body).to include("Serie 3")                 # chips por serie
    expect(response.body).to include("Escápulas retraídas")     # nota técnica
    expect(response.body).to include("Marcar día como hecho")
    expect(response.body).to include(registros_entrenamiento_path) # endpoint existente
  end

  it "serializa uid/series/descanso_seg en el JSON que consume el Stimulus" do
    crear_plan!(users(:one), rutina: rutina)
    sign_in_as users(:one)

    get sesion_path(lunes.iso8601)

    expect(response.body).to include('"uid":"abc123"')
    expect(response.body).to include('"series":3')
    expect(response.body).to include('"descanso_seg":90')
    # Rutinas sin uid caen al índice y sin descanso usan 60 s por defecto
    expect(response.body).to include('"uid":"1"')
    expect(response.body).to include('"descanso_seg":60')
  end

  it "sin plan publicado muestra el estado vacío con link a Mi plan" do
    sign_in_as users(:one)

    get sesion_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Aún no tienes un plan")
    expect(response.body).to include(mi_plan_path)
  end

  it "una fecha sin día programado en la rutina es descanso" do
    crear_plan!(users(:one), rutina: rutina) # solo lunes
    sign_in_as users(:one)

    get sesion_path((lunes + 6).iso8601) # domingo

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Hoy toca descanso")
    expect(response.body).to include(mi_plan_path)
  end

  it "cada quien ve su propia sesión: el plan de otro usuario no se filtra" do
    crear_plan!(users(:one), rutina: rutina)
    sign_in_as users(:two) # sin plan propio

    get sesion_path(lunes.iso8601)

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include("Press banca")
    expect(response.body).to include("Aún no tienes un plan")
  end

  it "con version: 2 toma la rutina base (rutina['dias']) igual" do
    crear_plan!(users(:one), rutina: rutina.merge("version" => 2))
    sign_in_as users(:one)

    get sesion_path(lunes.iso8601)

    expect(response.body).to include("Press banca")
  end

  it "una fecha inválida cae al día de hoy sin reventar" do
    sign_in_as users(:one)

    get "/sesion/2026-13-40" # pasa el constraint pero no es fecha ISO válida

    expect(response).to have_http_status(:success)
  end

  it "sin sesión iniciada redirige al login" do
    get sesion_path
    expect(response).to have_http_status(:redirect)
  end
end
