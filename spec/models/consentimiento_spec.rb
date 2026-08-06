require "rails_helper"

RSpec.describe Consentimiento, type: :model do
  let(:user) { users(:one) }

  def registrar(tipo: "tabla_posiciones", accion: "otorgado")
    Consentimiento.create!(user: user, tipo: tipo, accion: accion,
                           version_texto: "v1", ip: "127.0.0.1", user_agent: "spec")
  end

  it "valida tipo, accion y version_texto" do
    expect(registrar).to be_persisted

    invalido = Consentimiento.new(user: user, tipo: "otro", accion: "otorgado", version_texto: "v1")
    expect(invalido).not_to be_valid
    expect(invalido.errors[:tipo]).to be_present

    invalido = Consentimiento.new(user: user, tipo: "tabla_posiciones", accion: "quizas", version_texto: "v1")
    expect(invalido).not_to be_valid

    invalido = Consentimiento.new(user: user, tipo: "tabla_posiciones", accion: "otorgado", version_texto: "")
    expect(invalido).not_to be_valid
  end

  it "es append-only: una fila persistida no se edita ni se borra" do
    fila = registrar

    expect { fila.update!(accion: "revocado") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { fila.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect(Consentimiento.count).to eq 1
  end

  it "vigente?: otorgar → revocar → otorgar deja vigente con 3 filas de rastro" do
    registrar(accion: "otorgado")
    expect(Consentimiento.vigente?(user, "tabla_posiciones")).to be true

    registrar(accion: "revocado")
    expect(Consentimiento.vigente?(user, "tabla_posiciones")).to be false

    registrar(accion: "otorgado")
    expect(Consentimiento.vigente?(user, "tabla_posiciones")).to be true
    expect(user.consentimientos.where(tipo: "tabla_posiciones").count).to eq 3
  end

  it "vigente? es false sin filas y es independiente por tipo" do
    expect(Consentimiento.vigente?(user, "tabla_posiciones")).to be false

    registrar(tipo: "ciclo_menstrual", accion: "otorgado")
    expect(Consentimiento.vigente?(user, "ciclo_menstrual")).to be true
    expect(Consentimiento.vigente?(user, "ciclo_menstrual_ia")).to be false
    expect(Consentimiento.vigente?(user, "tabla_posiciones")).to be false
  end

  # Fase 18e: la versión en lote respeta la MISMA semántica de vigente?
  # (última fila por usuario decide).
  it "usuarios_vigentes devuelve solo a quienes tienen la última fila otorgada" do
    otro = users(:two)
    registrar(tipo: "logros_comunidad", accion: "otorgado")
    registrar(tipo: "logros_comunidad", accion: "revocado")

    Consentimiento.create!(user: otro, tipo: "logros_comunidad", accion: "otorgado",
                           version_texto: "v1")

    vigentes = Consentimiento.usuarios_vigentes("logros_comunidad", [ user.id, otro.id ])
    expect(vigentes).to eq [ otro.id ]
    expect(Consentimiento.usuarios_vigentes("logros_comunidad", [])).to eq []
  end
end
