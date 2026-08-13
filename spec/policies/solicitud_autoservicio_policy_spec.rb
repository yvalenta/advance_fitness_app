require "rails_helper"

RSpec.describe SolicitudAutoservicioPolicy do
  let(:solicitud) { SolicitudAutoservicio.create!(nombre: "Ana", email: "ana@x.com", telefono: "3001234567", segmento: "individual") }

  it "superadmin y comercializador pueden ver y actualizar" do
    superadmin = User.create!(email_address: "sa@x.com", password: "clave1234", rol: "superadmin", nombre: "SA")
    comercializador = User.create!(email_address: "co@x.com", password: "clave1234", rol: "comercializador", nombre: "Co")

    [ superadmin, comercializador ].each do |user|
      expect(described_class.new(user, solicitud).index?).to be true
      expect(described_class.new(user, solicitud).update?).to be true
    end
  end

  it "admin/entrenador/miembro no pueden" do
    [ users(:admin), users(:entrenador), users(:one) ].each do |user|
      expect(described_class.new(user, solicitud).index?).to be(false), "#{user.rol} no debería poder index?"
      expect(described_class.new(user, solicitud).update?).to be(false), "#{user.rol} no debería poder update?"
    end
  end
end
