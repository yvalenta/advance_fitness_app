require "rails_helper"

RSpec.describe SuscripcionPush, type: :model do
  let(:endpoint) { "https://fcm.googleapis.com/fcm/send/abc123" }

  it "exige endpoint, p256dh y auth" do
    suscripcion = described_class.new(user: users(:one))
    expect(suscripcion).not_to be_valid
    expect(suscripcion.errors.attribute_names).to include(:endpoint, :p256dh, :auth)
  end

  it "registrar! crea la fila del dispositivo" do
    suscripcion = described_class.registrar!(users(:one), endpoint: endpoint,
                                             p256dh: "clave-p", auth: "clave-a",
                                             user_agent: "iPhone")
    expect(suscripcion).to be_persisted
    expect(suscripcion.user).to eq(users(:one))
    expect(suscripcion.user_agent).to eq("iPhone")
  end

  it "registrar! con el mismo endpoint actualiza en vez de duplicar" do
    described_class.registrar!(users(:one), endpoint: endpoint, p256dh: "v1", auth: "a1")

    expect {
      described_class.registrar!(users(:one), endpoint: endpoint, p256dh: "v2", auth: "a2")
    }.not_to change(described_class, :count)
    expect(described_class.find_by(endpoint: endpoint).p256dh).to eq("v2")
  end

  it "el mismo dispositivo con otra cuenta cambia de dueño (la fila sigue al endpoint)" do
    described_class.registrar!(users(:one), endpoint: endpoint, p256dh: "v", auth: "a")

    described_class.registrar!(users(:entrenador), endpoint: endpoint, p256dh: "v", auth: "a")

    expect(described_class.where(endpoint: endpoint).count).to eq(1)
    expect(described_class.find_by(endpoint: endpoint).user).to eq(users(:entrenador))
  end
end
