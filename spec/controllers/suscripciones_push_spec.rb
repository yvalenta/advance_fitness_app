require "rails_helper"

RSpec.describe "SuscripcionesPush", type: :request do
  let(:endpoint) { "https://fcm.googleapis.com/fcm/send/abc123" }

  it "requiere sesión" do
    post suscripciones_push_path, params: { endpoint: endpoint }, as: :json
    expect(response).to redirect_to(new_session_path)
  end

  it "suscribe el dispositivo del usuario actual con su user agent" do
    sign_in_as users(:one)

    expect {
      post suscripciones_push_path,
           params: { endpoint: endpoint, p256dh: "clave-p", auth: "clave-a" },
           headers: { "User-Agent" => "iPhone Safari" }, as: :json
    }.to change(SuscripcionPush, :count).by(1)

    expect(response).to have_http_status(:created)
    suscripcion = SuscripcionPush.find_by(endpoint: endpoint)
    expect(suscripcion.user).to eq(users(:one))
    expect(suscripcion.user_agent).to eq("iPhone Safari")
  end

  it "re-suscribir el mismo endpoint no duplica (upsert)" do
    sign_in_as users(:one)
    SuscripcionPush.registrar!(users(:one), endpoint: endpoint, p256dh: "v1", auth: "a1")

    expect {
      post suscripciones_push_path,
           params: { endpoint: endpoint, p256dh: "v2", auth: "a2" }, as: :json
    }.not_to change(SuscripcionPush, :count)

    expect(SuscripcionPush.find_by(endpoint: endpoint).p256dh).to eq("v2")
  end

  it "retira el dispositivo propio por endpoint" do
    sign_in_as users(:one)
    SuscripcionPush.registrar!(users(:one), endpoint: endpoint, p256dh: "p", auth: "a")

    expect {
      delete suscripciones_push_path, params: { endpoint: endpoint }, as: :json
    }.to change(SuscripcionPush, :count).by(-1)
    expect(response).to have_http_status(:no_content)
  end

  it "el endpoint de OTRO usuario no se toca (scope solo-dueño) y responde igual" do
    sign_in_as users(:one)
    ajena = SuscripcionPush.registrar!(users(:two), endpoint: endpoint, p256dh: "p", auth: "a")

    expect {
      delete suscripciones_push_path, params: { endpoint: endpoint }, as: :json
    }.not_to change(SuscripcionPush, :count)

    expect(response).to have_http_status(:no_content)
    expect(SuscripcionPush.exists?(ajena.id)).to be(true)
  end
end
