require "rails_helper"

RSpec.describe Juego::Recalculador do
  let(:user) { users(:one) }
  let(:hoy) { Date.current }

  # Simula el flujo real: cada día de actividad pasa por Otorgador + Racha
  # (lo que haría OtorgarPuntosJob), con un Acceso como origen.
  def dia_de_actividad(fecha)
    acceso = Acceso.create!(user: user, fecha_hora: fecha.to_time.change(hour: 8))
    Juego::Otorgador.otorgar!(user, tipo: "checkin", origen: acceso, fecha: fecha)
    Juego::Racha.actualizar!(user, fecha: fecha)
  end

  it "borrar la proyección y reconstruir desde el ledger da el mismo resultado" do
    # 3 días seguidos, un hueco y 2 días más + un logro obtenido
    [ hoy - 6, hoy - 5, hoy - 4, hoy - 1, hoy ].each { |f| dia_de_actividad(f) }
    logro = Logro.create!(codigo: "primera-sesion", nombre: "Primera sesión",
                          puntos: 20, categoria: "constancia")
    LogroObtenido.create!(user: user, logro: logro, obtenido_en: Time.current)

    incremental = user.reload.perfil_juego.attributes
    user.perfil_juego.destroy!

    reconstruido = described_class.para(user)

    expect(reconstruido.puntos_total).to eq incremental["puntos_total"]
    expect(reconstruido.nivel).to eq incremental["nivel"]
    expect(reconstruido.racha_actual).to eq incremental["racha_actual"]
    expect(reconstruido.racha_mejor).to eq incremental["racha_mejor"]
    expect(reconstruido.ultima_fecha_racha).to eq incremental["ultima_fecha_racha"]
    expect(reconstruido.racha_actual).to eq 2
    expect(reconstruido.racha_mejor).to eq 3
    expect(reconstruido.logros_count).to eq 1
  end

  it "es idempotente: correrlo dos veces no cambia nada" do
    dia_de_actividad(hoy)
    primera = described_class.para(user).attributes
    segunda = described_class.para(user).attributes

    expect(segunda.except("updated_at")).to eq primera.except("updated_at")
  end

  it "corrige una proyección desfasada sin tocar las preferencias del miembro" do
    dia_de_actividad(hoy)
    perfil = user.reload.perfil_juego
    perfil.update!(puntos_total: 9_999, nivel: 42, visible_en_tabla: true, apodo: "La Máquina")

    described_class.para(user)
    perfil.reload

    expect(perfil.puntos_total).to eq 10
    expect(perfil.nivel).to eq 1
    expect(perfil.visible_en_tabla).to be true
    expect(perfil.apodo).to eq "La Máquina"
  end

  it "sin actividad deja todo en cero" do
    perfil = described_class.para(user)
    expect(perfil.puntos_total).to eq 0
    expect(perfil.racha_actual).to eq 0
    expect(perfil.racha_mejor).to eq 0
    expect(perfil.ultima_fecha_racha).to be_nil
  end
end
