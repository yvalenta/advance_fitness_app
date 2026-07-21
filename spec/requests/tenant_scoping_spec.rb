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

  it "un miembro del tenant A que pega el subdominio de otro tenant es rechazado" do
    tenants(:megaplex)  # existe
    sign_in_as users(:one)  # AF
    host! "megaplex.example.com"
    get root_path
    expect(response).to redirect_to(new_session_url)
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
