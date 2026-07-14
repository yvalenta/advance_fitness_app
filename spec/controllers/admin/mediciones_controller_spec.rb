require "rails_helper"

RSpec.describe "Admin::Mediciones", type: :request do
  it "el staff toma una medición del miembro (queda como tomada_por)" do
    sign_in_as users(:entrenador)

    expect {
      post admin_user_mediciones_path(users(:one)),
           params: { medicion: { peso_kg: 74, talla_cm: 176, cintura_cm: 80 } }
    }.to change(Medicion, :count).by(1)
    expect(response).to redirect_to(admin_user_mediciones_path(users(:one)))
    expect(users(:one).ultima_medicion.tomada_por).to eq(users(:entrenador))
  end

  it "el staff ve el historial del miembro" do
    users(:one).mediciones.create!(peso_kg: 80, fecha: Date.current)
    sign_in_as users(:admin)

    get admin_user_mediciones_path(users(:one))
    expect(response).to have_http_status(:success)
  end

  # Fase 5.13: "editar peso rápido" del popup no debe chocar con una medición
  # ya tomada el mismo día (upsert por fecha, preserva el resto de campos).
  it "tomar una segunda medición el mismo día corrige el peso sin duplicar" do
    users(:one).mediciones.create!(peso_kg: 80, cintura_cm: 82, fecha: Date.current, tomada_por: users(:admin))
    sign_in_as users(:entrenador)

    expect {
      post admin_user_mediciones_path(users(:one)), params: { medicion: { peso_kg: 79 } }
    }.not_to change(Medicion, :count)
    corregida = users(:one).ultima_medicion
    expect(corregida.peso_kg.to_f).to eq(79)
    expect(corregida.cintura_cm.to_f).to eq(82)
    expect(corregida.tomada_por).to eq(users(:entrenador))
  end

  it "un miembro no puede ver ni tomar mediciones de otros" do
    sign_in_as users(:one)

    get admin_user_mediciones_path(users(:entrenador))
    expect(response).to redirect_to(root_path)

    expect {
      post admin_user_mediciones_path(users(:entrenador)), params: { medicion: { peso_kg: 90 } }
    }.not_to change(Medicion, :count)
    expect(response).to redirect_to(root_path)
  end

  it "el staff edita una medición pasada sin duplicar el historial" do
    medicion = users(:one).mediciones.create!(peso_kg: 80, cintura_cm: 82, fecha: Date.current - 10)
    sign_in_as users(:admin)

    expect {
      patch admin_user_medicion_path(users(:one), medicion), params: { medicion: { peso_kg: 78 } }
    }.not_to change(Medicion, :count)
    expect(medicion.reload.peso_kg.to_f).to eq(78)
    expect(medicion.cintura_cm.to_f).to eq(82) # el resto de campos no se pisa
  end

  it "un miembro no puede editar mediciones de otros" do
    medicion = users(:entrenador).mediciones.create!(peso_kg: 80, fecha: Date.current)
    sign_in_as users(:one)

    patch admin_user_medicion_path(users(:entrenador), medicion), params: { medicion: { peso_kg: 60 } }
    expect(response).to redirect_to(root_path)
    expect(medicion.reload.peso_kg.to_f).to eq(80)
  end

  it "actualizar_plan=1 reencola la generación del plan Personalizado con la nueva medición" do
    plan = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "aprobado",
                                     aprobado_por: users(:entrenador), rutina: { "dias" => [] },
                                     plan_nutricional: { "kcal_diarias" => 0, "comidas" => [] })
    sign_in_as users(:entrenador)

    expect {
      post admin_user_mediciones_path(users(:one)),
           params: { medicion: { peso_kg: 74 }, actualizar_plan: "1" }
    }.to have_enqueued_job(GenerarPlanJob).with(plan.id)
    expect(plan.reload.estado).to eq("generando")
  end

  it "sin marcar actualizar_plan, el plan Personalizado no se toca" do
    plan = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "aprobado",
                                     aprobado_por: users(:entrenador), rutina: { "dias" => [] },
                                     plan_nutricional: { "kcal_diarias" => 0, "comidas" => [] })
    sign_in_as users(:entrenador)

    expect {
      post admin_user_mediciones_path(users(:one)), params: { medicion: { peso_kg: 74 } }
    }.not_to have_enqueued_job(GenerarPlanJob)
    expect(plan.reload.estado).to eq("aprobado")
  end

  it "actualizar_plan=1 no hace nada si el plan es el sugerido por reglas" do
    plan = PlanPersonalizado.create!(user: users(:one), generado_por: "reglas", estado: "aprobado",
                                     rutina: { "dias" => [] }, plan_nutricional: {})
    sign_in_as users(:entrenador)

    expect {
      post admin_user_mediciones_path(users(:one)), params: { medicion: { peso_kg: 74 }, actualizar_plan: "1" }
    }.not_to have_enqueued_job(GenerarPlanJob)
    expect(plan.reload.estado).to eq("aprobado")
  end
end
