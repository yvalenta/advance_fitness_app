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
