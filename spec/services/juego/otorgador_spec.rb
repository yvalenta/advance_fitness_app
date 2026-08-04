require "rails_helper"

RSpec.describe Juego::Otorgador do
  let(:user) { users(:one) }
  let(:acceso) { Acceso.create!(user: user, fecha_hora: Time.current) }

  it "usa los puntos por defecto del tipo y actualiza la proyección" do
    registro = described_class.otorgar!(user, tipo: "checkin", origen: acceso)

    expect(registro.puntos).to eq 10
    perfil = user.reload.perfil_juego
    expect(perfil.puntos_total).to eq 10
    expect(perfil.nivel).to eq 1
  end

  it "acepta puntos explícitos (logro, ajuste_manual) y exige que existan" do
    registro = described_class.otorgar!(user, tipo: "logro", puntos: 200)
    expect(registro.puntos).to eq 200
    expect(user.reload.perfil_juego.nivel).to eq 2 # 200 pts → nivel 2

    expect {
      described_class.otorgar!(user, tipo: "logro")
    }.to raise_error(ArgumentError, /puntos es obligatorio/)
  end

  it "es idempotente: el mismo (tipo, origen) dos veces deja UNA fila y devuelve nil" do
    primero = described_class.otorgar!(user, tipo: "checkin", origen: acceso)
    segundo = described_class.otorgar!(user, tipo: "checkin", origen: acceso)

    expect(primero).to be_persisted
    expect(segundo).to be_nil
    expect(user.registros_puntos.count).to eq 1
    expect(user.reload.perfil_juego.puntos_total).to eq 10
  end

  it "la proyección se RESUMA del ledger: varios otorgamientos acumulan bien" do
    described_class.otorgar!(user, tipo: "checkin", origen: acceso)
    described_class.otorgar!(user, tipo: "entrenamiento_completo",
                             origen: RegistroEntrenamiento.create!(user: user, fecha: Date.current))
    described_class.otorgar!(user, tipo: "racha_semanal")

    expect(user.reload.perfil_juego.puntos_total).to eq 10 + 15 + 25
  end
end
