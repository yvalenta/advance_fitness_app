require "rails_helper"

RSpec.describe OtorgarPuntosJob, type: :job do
  let(:user) { users(:one) }
  let(:acceso) { Acceso.create!(user: user, fecha_hora: Time.current) }

  it "IDEMPOTENCIA: ejecutarlo DOS veces con el mismo origen deja UNA fila y el total correcto" do
    2.times do
      described_class.perform_now(user.id, tipo: "checkin", fecha: Date.current,
                                  origen_gid: acceso.to_global_id.to_s)
    end

    expect(user.registros_puntos.count).to eq 1
    perfil = user.reload.perfil_juego
    expect(perfil.puntos_total).to eq 10
    expect(perfil.racha_actual).to eq 1
    expect(perfil.ultima_fecha_racha).to eq Date.current
  end

  it "el primer ejercicio hecho del día otorga entrenamiento_completo y racha" do
    registro = RegistroEntrenamiento.create!(user: user, fecha: Date.current)
    described_class.perform_now(user.id, tipo: "entrenamiento_completo", fecha: Date.current,
                                origen_gid: registro.to_global_id.to_s)

    fila = user.registros_puntos.sole
    expect(fila.tipo).to eq "entrenamiento_completo"
    expect(fila.puntos).to eq 15
    expect(fila.origen).to eq registro
    expect(user.reload.perfil_juego.racha_actual).to eq 1
  end

  it "si el user ya no existe, es no-op silencioso" do
    expect {
      described_class.perform_now(-1, tipo: "checkin", fecha: Date.current)
    }.not_to change(RegistroPunto, :count)
  end

  it "si el origen fue borrado antes de correr, es no-op silencioso" do
    gid = acceso.to_global_id.to_s
    acceso.destroy!

    expect {
      described_class.perform_now(user.id, tipo: "checkin", fecha: Date.current, origen_gid: gid)
    }.not_to change(RegistroPunto, :count)
  end
end
