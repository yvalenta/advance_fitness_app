require "rails_helper"

RSpec.describe "Landing::Autoservicios", type: :request do
  describe "trainer.ynt.codes — segmento entrenador" do
    before { host! "trainer.example.com" }

    it "muestra la landing con copy de entrenador" do
      get landing_autoservicio_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Quiero mi propio negocio")
    end

    it "se registra con nombre de negocio" do
      expect {
        post landing_autoservicios_path, params: {
          solicitud_autoservicio: { nombre: "Beto", email: "beto@x.com", telefono: "3007654321", negocio_nombre: "Beto Fit" }
        }
      }.to change(SolicitudAutoservicio, :count).by(1)

      expect(response).to redirect_to(landing_autoservicio_gracias_path)
      expect(SolicitudAutoservicio.last.segmento).to eq("entrenador")
    end

    it "sin nombre de negocio no pasa validación" do
      expect {
        post landing_autoservicios_path, params: {
          solicitud_autoservicio: { nombre: "Beto", email: "beto@x.com", telefono: "3007654321" }
        }
      }.not_to change(SolicitudAutoservicio, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "ignora un segmento enviado por el cliente — siempre gana el subdominio" do
      post landing_autoservicios_path, params: {
        solicitud_autoservicio: { nombre: "Beto", email: "beto@x.com", telefono: "3007654321",
                                   negocio_nombre: "Beto Fit", segmento: "individual" }
      }
      expect(SolicitudAutoservicio.last.segmento).to eq("entrenador")
    end
  end

  describe "entrena.ynt.codes — segmento individual" do
    before { host! "entrena.example.com" }

    it "muestra la landing con copy individual" do
      get landing_autoservicio_path
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Nombre de tu negocio o marca")
    end

    it "se registra sin necesitar negocio_nombre" do
      expect {
        post landing_autoservicios_path, params: {
          solicitud_autoservicio: { nombre: "Ana", email: "ana@x.com", telefono: "3001234567" }
        }
      }.to change(SolicitudAutoservicio, :count).by(1)

      expect(response).to redirect_to(landing_autoservicio_gracias_path)
      expect(SolicitudAutoservicio.last.segmento).to eq("individual")
    end

    it "la página de gracias responde" do
      get landing_autoservicio_gracias_path
      expect(response).to have_http_status(:success)
    end
  end
end
