require "rails_helper"

RSpec.describe "Progresos", type: :request do
  it "requiere sesión" do
    get progreso_path
    expect(response).to redirect_to(new_session_path)

    get progreso_grafica_path(tipo: "peso")
    expect(response).to redirect_to(new_session_path)
  end

  # Fase 16.6: la página carga solo el RESUMEN; cada gráfica llega por su
  # turbo-frame perezoso (src) — sin un solo <svg> inline en la página.
  it "la página trae el resumen y los frames perezosos de las gráficas" do
    user = users(:one)
    ObjetivoNutricional.fijar_para(user, tipo: "deficit", peso_kg: 72)
    ObjetivoNutricional.fijar_para(user, tipo: "deficit", peso_kg: 70)
    RegistroCaloria.registrar(user, kcal: 1800)

    sign_in_as user
    get progreso_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("70.0 kg") # peso actual (resumen)
    expect(response.body).to include("1 de 1 días registrados en meta")
    %w[peso calorias asistencia].each do |tipo|
      assert_select "turbo-frame#grafica_#{tipo}[src=?][loading=lazy]", progreso_grafica_path(tipo: tipo)
    end
    expect(response.body).not_to include("<svg aria-label=")
  end

  it "cada frame sirve SU gráfica con drill-down y nada más" do
    user = users(:one)
    ObjetivoNutricional.fijar_para(user, tipo: "deficit", peso_kg: 72)
    ObjetivoNutricional.fijar_para(user, tipo: "deficit", peso_kg: 70)
    RegistroCaloria.registrar(user, kcal: 1800)
    Acceso.registrar_para(user, user.membresia, ahora: Time.current.change(hour: 10))
    sign_in_as user

    get progreso_grafica_path(tipo: "peso")
    assert_select "svg[aria-label='Tendencia de peso']"
    assert_select "div[data-grafica-target=detalle]", 2 # snapshots de objetivos
    expect(response.body).to include("Este snapshot alimentó tus cálculos")

    get progreso_grafica_path(tipo: "calorias")
    assert_select "svg[aria-label='Calorías diarias contra el objetivo']"
    expect(response.body).to include("Fuente: tu registro diario de calorías")

    get progreso_grafica_path(tipo: "asistencia")
    assert_select "svg[aria-label='Visitas al gimnasio por semana']"
  end

  it "un tipo de gráfica fuera del contrato no rutea" do
    sign_in_as users(:one)
    get "/progreso/grafica/otra"
    expect(response).to have_http_status(:not_found)
  end

  it "sin datos los frames muestran estados vacíos con CTA" do
    sign_in_as users(:two)

    get progreso_path
    expect(response).to have_http_status(:success)

    get progreso_grafica_path(tipo: "peso")
    expect(response.body).to include("Registra tu peso al menos dos veces")

    get progreso_grafica_path(tipo: "calorias")
    expect(response.body).to include("Fija tu objetivo calórico")

    get progreso_grafica_path(tipo: "asistencia")
    expect(response.body).to include("check-ins en recepción aparecerán aquí")
  end
end
