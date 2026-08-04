require "rails_helper"

RSpec.describe Notificaciones::EnviadorPush, type: :model do
  let(:suscripcion) do
    SuscripcionPush.registrar!(users(:one), endpoint: "https://fcm.googleapis.com/x",
                               p256dh: "clave-p", auth: "clave-a")
  end

  it "envía el payload mínimo cifrado al endpoint del dispositivo" do
    capturado = nil
    allow(WebPush).to receive(:payload_send) { |**kwargs| capturado = kwargs }

    resultado = described_class.enviar(suscripcion, titulo: "Hola", cuerpo: "Mundo", url: "/", tag: "racha")

    expect(resultado).to be(true)
    expect(capturado[:endpoint]).to eq(suscripcion.endpoint)
    expect(capturado[:p256dh]).to eq("clave-p")
    payload = JSON.parse(capturado[:message])
    expect(payload).to eq({ "titulo" => "Hola", "cuerpo" => "Mundo", "url" => "/", "tag" => "racha" })
    expect(capturado[:vapid][:private_key]).to be_present
  end

  it "un endpoint muerto (410 Gone) borra la suscripción: auto-depuración" do
    allow(WebPush).to receive(:payload_send)
      .and_raise(WebPush::ExpiredSubscription.new(double(body: ""), "fcm"))

    resultado = described_class.enviar(suscripcion, titulo: "x", cuerpo: "y")

    expect(resultado).to be(false)
    expect(SuscripcionPush.exists?(suscripcion.id)).to be(false)
  end

  it "un fallo transitorio del push service no borra el dispositivo" do
    allow(WebPush).to receive(:payload_send)
      .and_raise(WebPush::ResponseError.new(double(body: "429"), "fcm"))

    resultado = described_class.enviar(suscripcion, titulo: "x", cuerpo: "y")

    expect(resultado).to be(false)
    expect(SuscripcionPush.exists?(suscripcion.id)).to be(true)
  end

  it "sin llave VAPID privada no intenta enviar" do
    sin_vapid do
      expect(WebPush).not_to receive(:payload_send)
      expect(described_class.enviar(suscripcion, titulo: "x", cuerpo: "y")).to be(false)
    end
  end

  private

  def sin_vapid
    anterior = ENV.delete("VAPID_PRIVATE_KEY")
    yield
  ensure
    ENV["VAPID_PRIVATE_KEY"] = anterior if anterior
  end
end
