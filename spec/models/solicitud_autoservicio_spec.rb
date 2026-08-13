require "rails_helper"

RSpec.describe SolicitudAutoservicio do
  it "exige nombre, correo y teléfono" do
    solicitud = described_class.new(segmento: "individual")
    expect(solicitud).not_to be_valid
    expect(solicitud.errors[:nombre]).to be_present
    expect(solicitud.errors[:email]).to be_present
    expect(solicitud.errors[:telefono]).to be_present
  end

  it "exige negocio_nombre solo cuando el segmento es entrenador" do
    entrenador = described_class.new(nombre: "Ana", email: "ana@x.com", telefono: "3001234567", segmento: "entrenador")
    expect(entrenador).not_to be_valid
    expect(entrenador.errors[:negocio_nombre]).to be_present

    individual = described_class.new(nombre: "Ana", email: "ana@x.com", telefono: "3001234567", segmento: "individual")
    expect(individual).to be_valid
  end

  it "rechaza un segmento fuera de la lista" do
    solicitud = described_class.new(nombre: "Ana", email: "ana@x.com", telefono: "3001234567", segmento: "gimnasio")
    expect(solicitud).not_to be_valid
    expect(solicitud.errors[:segmento]).to be_present
  end

  describe "#marcar_atendida!" do
    it "registra quién y cuándo" do
      solicitud = described_class.create!(nombre: "Ana", email: "ana@x.com", telefono: "3001234567", segmento: "individual")
      staff = User.create!(email_address: "sa@x.com", password: "clave1234", rol: "superadmin", nombre: "SA")

      solicitud.marcar_atendida!(por: staff)

      expect(solicitud.atendida?).to be true
      expect(solicitud.atendida_por).to eq(staff)
      expect(solicitud.atendida_en).to be_present
    end
  end

  describe ".pendientes" do
    it "excluye las ya atendidas" do
      pendiente = described_class.create!(nombre: "Ana", email: "ana@x.com", telefono: "3001234567", segmento: "individual")
      atendida = described_class.create!(nombre: "Beto", email: "beto@x.com", telefono: "3007654321", segmento: "individual",
                                          atendida_en: Time.current)

      expect(described_class.pendientes).to include(pendiente)
      expect(described_class.pendientes).not_to include(atendida)
    end
  end
end
