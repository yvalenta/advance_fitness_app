require "rails_helper"

RSpec.describe "Landing::Autoservicios", type: :request do
  before { host! "join.example.com" }

  it "muestra la landing sin sesión ni tenant" do
    get landing_autoservicio_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Soy entrenador")
  end

  it "también responde en unete.example.com" do
    host! "unete.example.com"
    get landing_autoservicio_path
    expect(response).to have_http_status(:success)
  end

  it "un individual se registra sin necesitar negocio_nombre" do
    expect {
      post landing_autoservicios_path, params: {
        solicitud_autoservicio: { nombre: "Ana", email: "ana@x.com", telefono: "3001234567", segmento: "individual" }
      }
    }.to change(SolicitudAutoservicio, :count).by(1)

    expect(response).to redirect_to(landing_autoservicio_gracias_path)
    expect(SolicitudAutoservicio.last.segmento).to eq("individual")
  end

  it "un entrenador sin nombre de negocio no pasa validación" do
    expect {
      post landing_autoservicios_path, params: {
        solicitud_autoservicio: { nombre: "Beto", email: "beto@x.com", telefono: "3007654321", segmento: "entrenador" }
      }
    }.not_to change(SolicitudAutoservicio, :count)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "la página de gracias responde" do
    get landing_autoservicio_gracias_path
    expect(response).to have_http_status(:success)
  end
end
