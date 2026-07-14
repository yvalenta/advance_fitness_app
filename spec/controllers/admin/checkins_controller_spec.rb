require "rails_helper"

RSpec.describe "Admin::Checkins", type: :request do
  it "un miembro no accede al panel de check-in" do
    sign_in_as users(:one)
    get admin_checkins_path
    expect(response).to redirect_to(root_path)
  end

  it "staff registra el check-in de una membresía activa" do
    sign_in_as users(:entrenador)

    expect {
      post admin_checkins_path, params: { user_id: users(:one).id }
    }.to change(Acceso, :count).by(1)
    expect(response).to redirect_to(admin_checkins_path)
    expect(Acceso.recientes.first.tipo).to eq("checkin")
  end

  it "membresía vencida no registra acceso y pide renovación" do
    sign_in_as users(:admin)

    expect {
      post admin_checkins_path, params: { user_id: users(:two).id }
    }.not_to change(Acceso, :count)
    expect(flash[:alert]).to match(/renovación/)
  end

  it "miembro sin membresía no registra acceso" do
    sign_in_as users(:admin)

    expect {
      post admin_checkins_path, params: { user_id: users(:entrenador).id }
    }.not_to change(Acceso, :count)
    expect(flash[:alert]).to match(/no tiene membresía/)
  end

  # Regla de negocio (SDD §10): el plan personalizado reemplaza la mensualidad.
  it "un miembro premium sin membresía activa entra igual" do
    sign_in_as users(:admin)
    # two tiene la membresía vencida; le damos plan personalizado activo
    Suscripcion.create!(user: users(:two), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)

    expect {
      post admin_checkins_path, params: { user_id: users(:two).id }
    }.to change(Acceso, :count).by(1)
    expect(flash[:notice]).to match(/plan personalizado/)
  end

  # Fase 5.13: cada fila de miembro trae los datos para el popup de resumen
  # (peso rápido, check-in, ficha) sin romper el acento del eyebrow.
  it "el índice trae el popup de resumen con los data-* por miembro" do
    sign_in_as users(:entrenador)

    get admin_checkins_path(q: "Uno")

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Administración")
    assert_select "dialog[data-resumen-miembro-target=dialogo]"
    assert_select "[data-resumen-miembro-id-param=?]", users(:one).id.to_s
    assert_select "[data-resumen-miembro-medicion-url-param=?]", admin_user_mediciones_path(users(:one))
    assert_select "[data-resumen-miembro-perfil-url-param=?]", admin_user_path(users(:one))
    # Fase 5.16: cierre de fondo manual, no <form method="dialog"> (dejaba
    # pasar el click al navbar detrás al cerrarse)
    assert_select "dialog[data-action*=cerrarEnBackdrop]"
    assert_select "form[method=dialog]", count: 0
  end

  it "el badge de horario no se corta en una sola línea" do
    Acceso.registrar_para(users(:one), users(:one).membresia, ahora: Time.current)
    sign_in_as users(:entrenador)

    get admin_checkins_path
    assert_select "span.badge.whitespace-nowrap", minimum: 1
  end
end
