require "rails_helper"

RSpec.describe "Objetivos", type: :request do
  # Criterio de aceptación Fase 4 (SDD §11): al fijar "bajar de peso" veo mi
  # objetivo kcal y el faltante del día se actualiza al registrar consumo.
  it "fijar déficit muestra el objetivo y el registro de consumo actualiza el faltante" do
    sign_in_as users(:one)

    post objetivo_path, params: { objetivo_nutricional: { tipo: "deficit", peso_kg: 70 } }
    expect(response).to redirect_to(objetivo_path)

    get objetivo_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("2.138") # objetivo kcal (TDEE 2638 − 500)

    post registros_calorias_path, params: { registro_caloria: { kcal_consumidas: 1200 } }
    follow_redirect!
    # Fase 14.4: la cabecera numérica ahora es la dona; el restante vive en
    # el centro del SVG (#dona-restantes). 2138 − 1200 = 938.
    assert_select "#dona-restantes", text: /938/
  end

  # Fase 14.16: la fase lútea suma su kcal_delta al presupuesto de la dona,
  # con la leyenda del porqué. Sin consentimiento, nada de esto existe.
  it "en fase lútea el presupuesto del día sube y se explica" do
    miembra = users(:one)
    sign_in_as miembra
    post objetivo_path, params: { objetivo_nutricional: { tipo: "deficit", peso_kg: 70 } }

    miembra.consentimientos.create!(tipo: "ciclo_menstrual", accion: "otorgado",
                                    version_texto: "ciclo-v1")
    # Día 21 de un ciclo de 28 → lútea (kcal_delta 150)
    CicloMenstrual.create!(user: miembra, creado_por: miembra,
                           fecha_inicio: Date.current - 20)

    get objetivo_path

    expect(response.body).to include("+150 kcal por tu fase")
    # 2138 (objetivo) + 150 = 2288 de presupuesto en la dona
    assert_select "#dona-restantes", text: /2.288/
  end

  # Fase 18c: el perfil incompleto ya no expulsa al hub de cuenta — la misma
  # página pide inline los 4 datos del TDEE y devuelve al flujo del objetivo.
  it "sin perfil completo muestra el mini-perfil inline en vez de expulsar" do
    sign_in_as users(:two)

    get new_objetivo_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Cuéntanos lo básico")
    expect(response.body).to include('value="nuevo_objetivo"')
  end

  it "crear el objetivo sin perfil completo sigue bloqueado" do
    sign_in_as users(:two)

    post objetivo_path, params: { objetivo_nutricional: { tipo: "deficit", peso_kg: 70 } }
    expect(response).to redirect_to(edit_perfil_path)
  end

  it "completar el mini-perfil devuelve a fijar el objetivo" do
    sign_in_as users(:two)

    patch perfil_path, params: { destino: "nuevo_objetivo",
                                 user: { nombre: "Usuario Dos", fecha_nacimiento: "1995-05-05",
                                         sexo: "F", talla_cm: 165, nivel_actividad: 1.4 } }

    expect(response).to redirect_to(new_objetivo_path)
    expect(users(:two).reload.perfil_nutricional_completo?).to be true
  end

  # Fase 18h: el peso del formulario de objetivo viene de la última medición
  # real (cierra el pendiente de la Nota de Fase 4).
  it "precarga el peso desde la última medición" do
    Medicion.create!(user: users(:one), fecha: Date.current - 1, peso_kg: 72.5,
                     tomada_por: users(:one))
    sign_in_as users(:one)

    get new_objetivo_path

    expect(response.body).to include('value="72.5"')
  end

  # Fase 18b: con plan aprobado con comidas, el consumo del día se registra
  # en un tap con el total del plan (kcal + macros).
  it "ofrece 'Cumplí mi plan de hoy' con las kcal del plan aprobado" do
    ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)
    PlanPersonalizado.create!(
      user: users(:one), generado_por: "entrenador", estado: "aprobado",
      aprobado_por: users(:entrenador),
      rutina: { "dias" => [ { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [] } ] },
      plan_nutricional: { "kcal_diarias" => 1950, "comidas" => [
        { "nombre" => "Avena", "kcal" => 950, "proteinas_g" => 40, "tipo" => "desayuno" },
        { "nombre" => "Pollo con arroz", "kcal" => 1000, "proteinas_g" => 55, "tipo" => "almuerzo" }
      ] })
    sign_in_as users(:one)

    get objetivo_path
    expect(response.body).to include("Cumplí mi plan de hoy")
    expect(response.body).to include('value="1950"')

    post registros_calorias_path, params: { registro_caloria: { kcal_consumidas: 1950, proteinas_g: 95 } }
    registro = users(:one).registros_calorias.find_by(fecha: Date.current)
    expect(registro.kcal_consumidas).to eq(1950)
    expect(registro.proteinas_g).to eq(95)
  end

  it "sin objetivo la página invita a fijarlo" do
    sign_in_as users(:one)

    get objetivo_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Fijar mi objetivo")
  end

  it "requiere sesión" do
    get objetivo_path
    expect(response).to redirect_to(new_session_path)
  end

  # Fase 5.11: el objetivo diario se puede ajustar a mano
  it "el miembro ajusta manualmente su objetivo diario" do
    ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)
    sign_in_as users(:one)

    patch objetivo_path, params: { objetivo_nutricional: { objetivo_kcal: 1900 } }

    expect(response).to redirect_to(objetivo_path)
    objetivo = users(:one).objetivo_activo
    expect(objetivo.objetivo_kcal).to eq(1900)
    expect(objetivo.ajustado_manualmente?).to be_truthy
  end

  it "un ajuste inválido no cambia el objetivo" do
    ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)
    original = users(:one).objetivo_activo.objetivo_kcal
    sign_in_as users(:one)

    patch objetivo_path, params: { objetivo_nutricional: { objetivo_kcal: 0 } }

    expect(users(:one).objetivo_activo.objetivo_kcal).to eq(original)
  end

  # Fase 5.11: al fijar el objetivo nace el plan sugerido de la membresía
  it "fijar el objetivo crea el plan sugerido si hay membresía activa" do
    sign_in_as users(:one)

    expect {
      post objetivo_path, params: { objetivo_nutricional: { tipo: "superavit", peso_kg: 70 } }
    }.to change(PlanPersonalizado, :count).by(1)
    expect(users(:one).plan_aprobado.reglas?).to be_truthy
  end
end
