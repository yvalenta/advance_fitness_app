require "rails_helper"

RSpec.describe "Progresos", type: :request do
  it "requiere sesión" do
    get progreso_path
    expect(response).to redirect_to(new_session_path)
  end

  it "muestra las gráficas con los datos del miembro" do
    user = users(:one)
    ObjetivoNutricional.fijar_para(user, tipo: "deficit", peso_kg: 72)
    ObjetivoNutricional.fijar_para(user, tipo: "deficit", peso_kg: 70)
    RegistroCaloria.registrar(user, kcal: 1800)
    Acceso.registrar_para(user, user.membresia, ahora: Time.current.change(hour: 10))

    sign_in_as user
    get progreso_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Tendencia de peso")
    expect(response.body).to include("70.0 kg") # peso actual
    assert_select "svg[aria-label='Tendencia de peso']"
    assert_select "svg[aria-label='Calorías diarias contra el objetivo']"
    assert_select "svg[aria-label='Visitas al gimnasio por semana']"
    expect(response.body).to include("1 de 1 días registrados en meta")

    # Drill-down: cada punto/barra tiene su panel de detalle con la fuente
    assert_select "div[data-grafica-target=detalle]", 2 + 14 + 8 # objetivos + días + semanas
    expect(response.body).to include("Este snapshot alimentó tus cálculos")
    expect(response.body).to include("Fuente: tu registro diario de calorías")
  end

  it "sin datos muestra estados vacíos con CTA" do
    sign_in_as users(:two)
    get progreso_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Registra tu peso al menos dos veces")
    expect(response.body).to include("Fija tu objetivo calórico")
    expect(response.body).to include("check-ins en recepción aparecerán aquí")
  end
end
