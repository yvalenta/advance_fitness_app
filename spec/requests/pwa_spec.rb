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

  # Fase 14.1: identidad de instalación, ícono 192 y accesos rápidos.
  it "el manifest declara id, orientación, íconos 192/512 y shortcuts" do
    get "/manifest.json"

    json = JSON.parse(response.body)
    expect(json["id"]).to eq("/")
    expect(json["orientation"]).to eq("portrait")
    expect(json["icons"].map { |icono| icono["sizes"] }).to include("192x192", "512x512")
    expect(json["shortcuts"].map { |atajo| atajo["url"] })
      .to contain_exactly("/mi_plan", "/objetivo", "/progreso")
  end

  it "sirve el service worker con precache y fallback offline (Fase 14.1)" do
    get "/service-worker.js"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('addEventListener("fetch"')
    expect(response.body).to include("/offline.html")
    # Turbo: solo GET se intercepta; POST/streams pasan directo a la red.
    expect(response.body).to include('request.method !== "GET"')
  end

  it "la página offline estática existe para el fallback del service worker" do
    get "/offline.html"

    expect(response).to have_http_status(:ok)
    # Rack::Files entrega el estático como BINARY; se fuerza UTF-8 para comparar
    expect(response.body.force_encoding(Encoding::UTF_8)).to include("Sin conexión")
  end
end
