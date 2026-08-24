require "rails_helper"

RSpec.describe NotificarDescansoJob, type: :job do
  let(:user) { users(:one) }

  def suscribir(user, sufijo = "x")
    SuscripcionPush.registrar!(user, endpoint: "https://fcm.googleapis.com/#{sufijo}",
                               p256dh: "p", auth: "a")
  end

  before { allow(Notificaciones::EnviadorPush).to receive(:enviar).and_return(true) }

  it "envía el push a cada dispositivo suscrito cuando el token sigue vigente" do
    user.update!(descanso_push_activo: true, descanso_push_token: "tok1")
    telefono = suscribir(user, "tel")

    described_class.perform_now(user.id, "Serie 2 de 3 · Press banca", "tok1")

    expect(Notificaciones::EnviadorPush).to have_received(:enviar)
      .with(telefono, hash_including(titulo: "⏱️ Tu tiempo terminó", cuerpo: "Serie 2 de 3 · Press banca", tag: "descanso"))
    expect(user.reload.descanso_push_token).to be_nil
  end

  it "no envía nada si el token ya no coincide (se canceló o se programó otro)" do
    user.update!(descanso_push_activo: true, descanso_push_token: "tok-nuevo")
    suscribir(user)

    described_class.perform_now(user.id, "x", "tok-viejo")

    expect(Notificaciones::EnviadorPush).not_to have_received(:enviar)
  end

  it "no envía nada si se canceló (token en blanco)" do
    user.update!(descanso_push_activo: true, descanso_push_token: nil)
    suscribir(user)

    described_class.perform_now(user.id, "x", "tok1")

    expect(Notificaciones::EnviadorPush).not_to have_received(:enviar)
  end

  it "no envía nada si el miembro desactivó el aviso mientras tanto" do
    user.update!(descanso_push_activo: false, descanso_push_token: "tok1")
    suscribir(user)

    described_class.perform_now(user.id, "x", "tok1")

    expect(Notificaciones::EnviadorPush).not_to have_received(:enviar)
  end

  it "sin dispositivos suscritos no revienta" do
    user.update!(descanso_push_activo: true, descanso_push_token: "tok1")

    expect { described_class.perform_now(user.id, "x", "tok1") }.not_to raise_error
    expect(Notificaciones::EnviadorPush).not_to have_received(:enviar)
  end

  it "sin llaves VAPID es un no-op" do
    user.update!(descanso_push_activo: true, descanso_push_token: "tok1")
    suscribir(user)

    anterior = ENV.delete("VAPID_PRIVATE_KEY")
    begin
      described_class.perform_now(user.id, "x", "tok1")
    ensure
      ENV["VAPID_PRIVATE_KEY"] = anterior if anterior
    end

    expect(Notificaciones::EnviadorPush).not_to have_received(:enviar)
  end
end
