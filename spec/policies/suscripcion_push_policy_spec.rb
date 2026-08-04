require "rails_helper"

# Solo-dueño sin rama de staff (mismo blindaje que CicloMenstrualPolicy):
# estos specs fallan a propósito si alguien agrega `user.staff?` al Scope.
RSpec.describe SuscripcionPushPolicy do
  let(:dueno) { users(:one) }
  let(:otra) { users(:two) }
  let(:admin) { users(:admin) }

  let(:suscripcion) do
    SuscripcionPush.registrar!(dueno, endpoint: "https://fcm.googleapis.com/x",
                               p256dh: "p", auth: "a")
  end

  it "el dueño suscribe y retira su dispositivo" do
    expect(described_class.new(dueno, suscripcion).create?).to be(true)
    expect(described_class.new(dueno, suscripcion).destroy?).to be(true)
  end

  it "nadie más — ni el admin del propio tenant" do
    [ otra, admin, users(:entrenador) ].each do |quien|
      expect(described_class.new(quien, suscripcion).create?).to be(false)
      expect(described_class.new(quien, suscripcion).destroy?).to be(false)
    end
  end

  describe "Scope" do
    it "el dueño ve solo lo suyo" do
      suscripcion
      SuscripcionPush.registrar!(otra, endpoint: "https://fcm.googleapis.com/y",
                                 p256dh: "p", auth: "a")

      resuelto = described_class::Scope.new(dueno, SuscripcionPush).resolve
      expect(resuelto).to contain_exactly(suscripcion)
    end

    it "el staff del mismo tenant obtiene scope VACÍO (sin rama de staff)" do
      suscripcion
      expect(described_class::Scope.new(admin, SuscripcionPush).resolve).to be_empty
      expect(described_class::Scope.new(users(:entrenador), SuscripcionPush).resolve).to be_empty
    end
  end
end
