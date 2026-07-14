require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  it "un miembro no accede a la ficha de otro" do
    sign_in_as users(:one)
    get admin_user_path(users(:two))
    expect(response).to redirect_to(root_path)
  end

  it "el staff ve la ficha con la card de plan" do
    sign_in_as users(:entrenador)
    get admin_user_path(users(:one))

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Sin plan aún")
  end

  # Fase 5.13: la ficha del miembro enlaza directo a su plan (editor de staff)
  it "con un plan, la ficha enlaza al editor del plan" do
    plan = PlanPersonalizado.create!(user: users(:one), generado_por: "reglas",
                                     estado: "aprobado", rutina: { "dias" => [] }, plan_nutricional: {})
    sign_in_as users(:entrenador)

    get admin_user_path(users(:one))

    expect(response).to have_http_status(:success)
    assert_select "a[href=?]", plan_personalizado_path(plan)
  end

  # Fase 6.11: el staff busca al miembro por nombre o correo
  it "el listado filtra por nombre o correo con ?q=" do
    sign_in_as users(:entrenador)

    get admin_users_path(q: users(:one).nombre)
    expect(response).to have_http_status(:success)
    expect(response.body).to include(users(:one).email_address)
    expect(response.body).not_to include(users(:two).email_address)

    get admin_users_path(q: users(:two).email_address)
    expect(response).to have_http_status(:success)
    expect(response.body).to include(users(:two).email_address)
    expect(response.body).not_to include(users(:one).email_address)
  end

  # Fase 6.13: dashboard del miembro — datos básicos, gráficas de progreso
  it "el staff ve las gráficas de progreso en la ficha" do
    user = users(:one)
    ObjetivoNutricional.fijar_para(user, tipo: "deficit", peso_kg: 72)
    ObjetivoNutricional.fijar_para(user, tipo: "deficit", peso_kg: 70)
    RegistroCaloria.registrar(user, kcal: 1800)
    Acceso.registrar_para(user, user.membresia, ahora: Time.current.change(hour: 10))
    sign_in_as users(:entrenador)

    get admin_user_path(user)

    expect(response).to have_http_status(:success)
    assert_select "svg[aria-label='Tendencia de peso']"
    assert_select "svg[aria-label='Calorías diarias contra el objetivo']"
    assert_select "svg[aria-label='Visitas al gimnasio por semana']"
  end

  it "el entrenador edita datos básicos pero no puede cambiar el rol" do
    sign_in_as users(:entrenador)
    patch admin_user_path(users(:one)), params: { user: { nombre: "Nuevo Nombre", rol: "admin" } }

    expect(response).to redirect_to(admin_user_path(users(:one)))
    users(:one).reload
    expect(users(:one).nombre).to eq("Nuevo Nombre")
    expect(users(:one).rol).to eq("miembro")
  end

  it "el admin sí puede cambiar el rol" do
    sign_in_as users(:admin)
    patch admin_user_path(users(:one)), params: { user: { nombre: users(:one).nombre, rol: "entrenador" } }

    expect(response).to redirect_to(admin_user_path(users(:one)))
    expect(users(:one).reload.rol).to eq("entrenador")
  end

  it "un miembro no puede editar el perfil de otro" do
    sign_in_as users(:one)
    patch admin_user_path(users(:two)), params: { user: { nombre: "Hackeado" } }

    expect(response).to redirect_to(root_path)
    expect(users(:two).reload.nombre).not_to eq("Hackeado")
  end
end
