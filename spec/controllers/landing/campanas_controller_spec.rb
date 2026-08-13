require "rails_helper"

RSpec.describe "Landing::Campanas", type: :request do
  before { host! "join.example.com" }

  it "muestra la landing de campaña de un tenant existente" do
    get landing_campana_path(slug: tenants(:advance_fitness).slug)
    expect(response).to have_http_status(:success)
    expect(response.body).to include(tenants(:advance_fitness).nombre)
  end

  it "también responde en unete.example.com" do
    host! "unete.example.com"
    get landing_campana_path(slug: tenants(:advance_fitness).slug)
    expect(response).to have_http_status(:success)
  end

  it "un slug desconocido muestra la página de campaña no encontrada, no un 500" do
    get landing_campana_path(slug: "no-existe")
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Campaña no encontrada")
  end
end
