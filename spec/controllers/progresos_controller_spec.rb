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
    %w[peso calorias asistencia una_rm heatmap mapa_muscular].each do |tipo|
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
    ejercicio = Ejercicio.create!(dataset_id: "test-progreso", nombre: "Press de banca", nombre_en: "Bench press",
                                  nombre_normalizado: "press de banca", categoria: "fuerza", musculo: "pecho")
    registro = RegistroEntrenamiento.create!(user: user, fecha: Date.current)
    registro.detalles.create!(ejercicio: ejercicio, serie: 1, repeticiones: 5, peso_kg: 80)
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

    get progreso_grafica_path(tipo: "una_rm")
    expect(response.body).to include("Press de banca")
    expect(response.body).to include("93.3 kg") # Epley: 80 × (1 + 5/30)

    get progreso_grafica_path(tipo: "heatmap")
    assert_select "svg[aria-label='Días de actividad del último año']"

    get progreso_grafica_path(tipo: "mapa_muscular")
    assert_select "svg[aria-label='Mapa muscular — Frente']"
    assert_select "svg[aria-label='Mapa muscular — Espalda']"
    expect(response.body).to include("Sin trabajar en este período")
  end

  it "mapa_muscular respeta el período elegido y por defecto usa semana" do
    sign_in_as users(:one)

    get progreso_grafica_path(tipo: "mapa_muscular")
    assert_select "a.btn-active", text: "Semana"

    get progreso_grafica_path(tipo: "mapa_muscular", periodo: "mes")
    assert_select "a.btn-active", text: "Mes"

    get progreso_grafica_path(tipo: "mapa_muscular", periodo: "algo_invalido")
    assert_select "a.btn-active", text: "Semana"
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

    get progreso_grafica_path(tipo: "una_rm")
    expect(response.body).to include("Registra series con peso (1-12 repeticiones)")

    get progreso_grafica_path(tipo: "heatmap")
    expect(response.body).to include("Tu actividad del último año aparecerá aquí")

    get progreso_grafica_path(tipo: "mapa_muscular")
    expect(response.body).to include("Registra series en tus sesiones para ver qué músculos trabajaste")
  end
end
