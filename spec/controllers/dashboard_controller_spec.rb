require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  it "redirects to login when unauthenticated" do
    get root_url
    expect(response).to redirect_to(new_session_url)
  end

  it "shows dashboard when authenticated" do
    user = users(:one)
    post session_url, params: { email_address: user.email_address, password: "password" }

    get root_url
    expect(response).to have_http_status(:success)
    # El saludo usa solo el primer nombre del miembro
    assert_select "h1", text: /#{user.nombre.split.first}/
    # Fase 5.14: copy sin menciones a "IA" de cara al miembro
    expect(response.body).to include("Planes personalizados")
    expect(response.body).not_to match(/\bIA\b/)
  end
end
