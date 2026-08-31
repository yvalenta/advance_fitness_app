require "rails_helper"

RSpec.describe "Resolución de tenant por subdominio (SDD §16.6)", type: :request do
  before { host! "advance-fitness.example.com" }

  it "un subdominio de tenant conocido resuelve al tenant" do
    host! "advance-fitness.example.com"
    sign_in_as users(:one)
    get root_path
    expect(response).to have_http_status(:success)
  end

  it "advance-fitness-app.* cae por back-compat al tenant advance-fitness" do
    host! "advance-fitness-app.example.com"
    sign_in_as users(:one)
    get root_path
    expect(response).to have_http_status(:success)
  end

  it "un subdominio inexistente devuelve 404" do
    host! "no-existe.example.com"
    get "/"
    expect(response).to have_http_status(:not_found)
  end

  # `host!` antes de `sign_in_as`: con la cookie host-only (SDD §16.6) el
  # navegador nunca la mandaría al otro subdominio, así que firmar primero y
  # cambiar de host después redirige por FALTA de sesión y el test pasaría
  # aunque `verificar_pertenencia_al_tenant` no existiera. El flash es lo que
  # distingue las dos rutas: `request_authentication` no pone ninguno.
  it "un miembro del tenant A que pega el subdominio de otro tenant es rechazado" do
    tenants(:megaplex)  # existe
    host! "megaplex.example.com"
    sign_in_as users(:one)  # AF
    get root_path
    expect(response).to redirect_to(new_session_url)
    expect(flash[:alert]).to match(/pertenece a otro gimnasio/i)
  end

  # La defensa de revocación (tarea 2026-08-31): la pertenencia sale del
  # PUESTO, así que quitarlo mata la sesión viva en el siguiente request —
  # con la cache users.tenant_id la sesión sobrevivía a la revocación.
  it "sesión viva + puesto revocado → logout inmediato y sesión terminada" do
    sign_in_as users(:one)
    get root_path
    expect(response).to have_http_status(:success)

    puestos(:one).destroy!

    get root_path
    expect(response).to redirect_to(new_session_url)
    expect(flash[:alert]).to match(/pertenece a otro gimnasio/i)
    # terminate_session de verdad: la cookie no sirve para reintentar.
    expect(Session.where(user_id: users(:one).id)).to be_empty
  end

  it "con puesto acá pero la cuenta ESTACIONADA en otra organización → logout (solo el embudo re-estaciona)" do
    # users(:one) gana un puesto en megaplex y se estaciona allá; presenta
    # su sesión en el subdominio de AF, donde SÍ tiene puesto. Sin este
    # corte, las policies leerían la cache (tenant/rol de megaplex) bajo el
    # branding de advance-fitness.
    users(:one).puestos.create!(tenant: tenants(:megaplex), rol: "miembro")
    sign_in_as users(:one)
    users(:one).estacionar_en!(tenants(:megaplex))

    get root_path
    expect(response).to redirect_to(new_session_url)
    expect(flash[:alert]).to match(/activa en otra organización/i)
    expect(Session.where(user_id: users(:one).id)).to be_empty
  end

  it "en modo comercial, solo superadmin/comercializador pueden entrar" do
    host! "comercial.example.com"
    sign_in_as users(:one)  # miembro de AF
    get root_path
    expect(response).to redirect_to(new_session_url)
  end

  it "un superadmin puede entrar en modo comercial" do
    superadmin = User.create!(email_address: "sa@x.com", password: "clave1234", rol: "superadmin", nombre: "SA")
    host! "comercial.example.com"
    sign_in_as superadmin
    get superadmin_tenants_path
    expect(response).to have_http_status(:success)
  end
end
