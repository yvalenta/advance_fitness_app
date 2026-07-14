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
    assert_select "#kcal-restantes", text: /938/
  end

  it "sin perfil completo redirige a completar perfil" do
    sign_in_as users(:two)

    get new_objetivo_path
    expect(response).to redirect_to(edit_perfil_path)
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
