require "rails_helper"

RSpec.describe "DescansoPush", type: :request do
  let(:user) { users(:one) }

  def suscribir(user, sufijo = "x")
    SuscripcionPush.registrar!(user, endpoint: "https://fcm.googleapis.com/#{sufijo}", p256dh: "p", auth: "a")
  end

  describe "POST /descanso_push" do
    it "programa el job, guarda el token vigente y lo devuelve" do
      user.update!(descanso_push_activo: true)
      suscribir(user)
      sign_in_as user

      expect {
        post descanso_push_path, params: { segundos: 90, mensaje: "Serie 2 de 3" }
      }.to have_enqueued_job(NotificarDescansoJob).at(a_value_within(2).of(90.seconds.from_now))

      expect(response).to have_http_status(:success)
      token = JSON.parse(response.body)["token"]
      expect(token).to be_present
      expect(user.reload.descanso_push_token).to eq(token)
    end

    it "sin el toggle activado no programa nada (token nulo)" do
      user.update!(descanso_push_activo: false)
      suscribir(user)
      sign_in_as user

      expect {
        post descanso_push_path, params: { segundos: 90, mensaje: "x" }
      }.not_to have_enqueued_job(NotificarDescansoJob)
      expect(JSON.parse(response.body)["token"]).to be_nil
      expect(user.reload.descanso_push_token).to be_nil
    end

    it "sin ningún dispositivo suscrito no programa nada, aunque el toggle esté activo" do
      user.update!(descanso_push_activo: true)
      sign_in_as user

      expect {
        post descanso_push_path, params: { segundos: 90, mensaje: "x" }
      }.not_to have_enqueued_job(NotificarDescansoJob)
    end

    it "recorta segundos fuera de rango al tope de 900" do
      user.update!(descanso_push_activo: true)
      suscribir(user)
      sign_in_as user

      expect {
        post descanso_push_path, params: { segundos: 999_999, mensaje: "x" }
      }.to have_enqueued_job(NotificarDescansoJob).at(a_value_within(2).of(900.seconds.from_now))
    end

    it "programar un segundo aviso invalida el token del primero" do
      user.update!(descanso_push_activo: true)
      suscribir(user)
      sign_in_as user

      post descanso_push_path, params: { segundos: 90, mensaje: "primero" }
      primer_token = JSON.parse(response.body)["token"]

      post descanso_push_path, params: { segundos: 60, mensaje: "segundo" }
      segundo_token = JSON.parse(response.body)["token"]

      expect(segundo_token).not_to eq(primer_token)
      expect(user.reload.descanso_push_token).to eq(segundo_token)
    end
  end

  describe "DELETE /descanso_push" do
    it "limpia el token vigente (cancela el aviso pendiente)" do
      user.update!(descanso_push_activo: true, descanso_push_token: "tok1")
      sign_in_as user

      delete descanso_push_path

      expect(response).to have_http_status(:no_content)
      expect(user.reload.descanso_push_token).to be_nil
    end

    it "sin nada pendiente responde 204 igual (idempotente)" do
      sign_in_as user

      delete descanso_push_path

      expect(response).to have_http_status(:no_content)
    end
  end
end
