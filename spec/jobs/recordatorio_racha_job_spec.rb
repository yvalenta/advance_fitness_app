require "rails_helper"

RSpec.describe RecordatorioRachaJob, type: :job do
  let(:miembro) { users(:one) }

  def perfil_con_racha(user, ultima:, dias: 5)
    PerfilJuego.para(user).tap do |perfil|
      perfil.update!(racha_actual: dias, ultima_fecha_racha: ultima)
    end
  end

  def suscribir(user, sufijo = "x")
    SuscripcionPush.registrar!(user, endpoint: "https://fcm.googleapis.com/#{sufijo}",
                               p256dh: "p", auth: "a")
  end

  before { allow(Notificaciones::EnviadorPush).to receive(:enviar).and_return(true) }

  it "recuerda a quien entrenó AYER, en cada dispositivo, y marca la fecha" do
    perfil = perfil_con_racha(miembro, ultima: Date.current - 1, dias: 5)
    telefono = suscribir(miembro, "tel")
    tablet = suscribir(miembro, "tab")

    described_class.perform_now

    expect(Notificaciones::EnviadorPush).to have_received(:enviar)
      .with(telefono, hash_including(cuerpo: include("5 días"), tag: "racha"))
    expect(Notificaciones::EnviadorPush).to have_received(:enviar)
      .with(tablet, anything)
    expect(perfil.reload.racha_recordada_en).to eq(Date.current)
  end

  it "una segunda corrida el mismo día NO duplica el aviso (idempotencia)" do
    perfil_con_racha(miembro, ultima: Date.current - 1)
    suscribir(miembro)

    described_class.perform_now
    described_class.perform_now

    expect(Notificaciones::EnviadorPush).to have_received(:enviar).once
  end

  it "quien ya entrenó HOY no se molesta y quien perdió la racha no recibe culpa" do
    perfil_con_racha(miembro, ultima: Date.current)                    # ya entrenó
    perfil_con_racha(users(:entrenador), ultima: Date.current - 2)     # racha rota
    suscribir(miembro, "a")
    suscribir(users(:entrenador), "b")

    described_class.perform_now

    expect(Notificaciones::EnviadorPush).not_to have_received(:enviar)
  end

  it "sin dispositivos suscritos el perfil ni se marca" do
    perfil = perfil_con_racha(miembro, ultima: Date.current - 1)

    described_class.perform_now

    expect(Notificaciones::EnviadorPush).not_to have_received(:enviar)
    expect(perfil.reload.racha_recordada_en).to be_nil
  end

  it "con gamificación apagada en su gimnasio no se avisa ni se marca (Nota 23g)" do
    users(:two).update_columns(tenant_id: tenants(:megaplex).id)      # parado en otro gimnasio
    perfil = perfil_con_racha(miembro, ultima: Date.current - 1)
    otro = perfil_con_racha(users(:two), ultima: Date.current - 1)
    suscribir(miembro, "a")
    telefono_otro = suscribir(users(:two), "b")
    tenants(:advance_fitness).update!(features_habilitadas: { "gamificacion" => false })

    described_class.perform_now

    expect(Notificaciones::EnviadorPush).to have_received(:enviar).once
    expect(Notificaciones::EnviadorPush).to have_received(:enviar).with(telefono_otro, anything)
    expect(perfil.reload.racha_recordada_en).to be_nil
    expect(otro.reload.racha_recordada_en).to eq(Date.current)
  end

  # Hallado el 23-sep-2026: tras un cambio de gimnasio el perfil quedaba con el
  # tenant viejo y `perfil.update!` levantaba RecordInvalid — el `find_each` se
  # cortaba ahí y NADIE de los que venían detrás recibía el aviso ese día. El
  # orden importa: el perfil se crea ANTES del cambio (el caso real) y con id
  # menor, para que el find_each lo toque primero.
  it "tras un cambio de gimnasio el job no se corta: el perfil sigue a la cuenta y los demás reciben su aviso" do
    movido = users(:two)
    movido.puestos.create!(tenant: tenants(:megaplex), rol: "miembro")
    perfil_movido = perfil_con_racha(movido, ultima: Date.current - 1)
    perfil = perfil_con_racha(miembro, ultima: Date.current - 1)
    telefono_movido = suscribir(movido, "movido")
    telefono = suscribir(miembro, "otro")

    movido.estacionar_en!(tenants(:megaplex))
    expect(perfil_movido.id).to be < perfil.id

    expect { described_class.perform_now }.not_to raise_error

    expect(Notificaciones::EnviadorPush).to have_received(:enviar).with(telefono_movido, anything)
    expect(Notificaciones::EnviadorPush).to have_received(:enviar).with(telefono, anything)
    expect(perfil_movido.reload.racha_recordada_en).to eq(Date.current)
    expect(perfil.reload.racha_recordada_en).to eq(Date.current)
  end

  it "sin llaves VAPID el job es un no-op" do
    perfil_con_racha(miembro, ultima: Date.current - 1)
    suscribir(miembro)

    anterior = ENV.delete("VAPID_PRIVATE_KEY")
    begin
      described_class.perform_now
    ensure
      ENV["VAPID_PRIVATE_KEY"] = anterior if anterior
    end

    expect(Notificaciones::EnviadorPush).not_to have_received(:enviar)
  end
end
