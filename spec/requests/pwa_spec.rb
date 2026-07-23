require "rails_helper"

RSpec.describe "PWA", type: :request do
  it "sirve el manifest con el nombre y theme_color del Negocio" do
    get "/manifest.json"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    json = JSON.parse(response.body)
    expect(json["name"]).to eq(Negocio.nombre)
    expect(json["start_url"]).to eq("/")
    expect(json["display"]).to eq("standalone")
    expect(json["theme_color"]).to match(/\A#[0-9a-fA-F]{3,8}\z/)
  end

  it "sirve el service worker" do
    get "/service-worker.js"

    expect(response).to have_http_status(:ok)
  end
end
