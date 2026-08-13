require "rails_helper"

RSpec.describe "Superadmin::SolicitudesAutoservicio", type: :request do
  let(:superadmin) do
    User.create!(email_address: "sa@x.com", password: "clave1234", rol: "superadmin", nombre: "SA")
  end
  let!(:solicitud) do
    SolicitudAutoservicio.create!(nombre: "Ana", email: "ana@x.com", telefono: "3001234567", segmento: "individual")
  end

  before { host! "comercial.example.com" }

  it "el admin de un tenant no puede acceder" do
    host! "advance-fitness.example.com"
    sign_in_as users(:admin)
    get superadmin_solicitudes_autoservicio_path
    expect(response).to redirect_to(root_path)
  end

  it "el superadmin lista las solicitudes" do
    sign_in_as superadmin
    get superadmin_solicitudes_autoservicio_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Ana")
  end

  it "el comercializador también puede listar y marcar atendida" do
    comercializador = User.create!(email_address: "co@x.com", password: "clave1234", rol: "comercializador", nombre: "Co")
    sign_in_as comercializador

    get superadmin_solicitudes_autoservicio_path
    expect(response).to have_http_status(:success)

    patch superadmin_solicitud_autoservicio_path(solicitud)
    expect(solicitud.reload.atendida?).to be true
    expect(solicitud.atendida_por).to eq(comercializador)
  end
end
