require "rails_helper"

# Los DISPAROS del motor de juego (Fase 14.12) viven en los controllers —
# jamás en callbacks de modelo (demo:sembrar crearía miles de puntos). Este
# spec fija ese contrato: check-in del admin y primer ejercicio marcado del
# día encolan OtorgarPuntosJob; el resto de marcas del día, no.
RSpec.describe "Enganches del motor de juego", type: :request do
  before { host! "advance-fitness.example.com" }

  let(:miembro) { users(:one) }
  let(:admin) { users(:admin) }

  describe "POST /admin/checkins (Admin::CheckinsController)" do
    # users(:one) ya tiene membresía activa vía fixture (membresias:activa_one)
    before { sign_in_as admin }

    it "encola OtorgarPuntosJob con el acceso como origen" do
      expect {
        post admin_checkins_path, params: { user_id: miembro.id }
      }.to have_enqueued_job(OtorgarPuntosJob).with { |user_id, tipo:, fecha:, origen_gid:|
        expect(user_id).to eq miembro.id
        expect(tipo).to eq "checkin"
        expect(fecha).to eq Date.current
        expect(origen_gid).to eq Acceso.last.to_global_id.to_s
      }
    end
  end

  describe "POST /registros_entrenamiento (RegistrosEntrenamientoController)" do
    before { sign_in_as miembro }

    it "el PRIMER ejercicio hecho del día encola el job; los siguientes no (un job por día)" do
      expect {
        post registros_entrenamiento_path,
             params: { fecha: Date.current.iso8601, indice: 0, hecho: "true", nombre: "Sentadilla" }
      }.to have_enqueued_job(OtorgarPuntosJob).with { |_user_id, tipo:, **|
        expect(tipo).to eq "entrenamiento_completo"
      }

      expect {
        post registros_entrenamiento_path,
             params: { fecha: Date.current.iso8601, indice: 1, hecho: "true", nombre: "Press banca" }
      }.not_to have_enqueued_job(OtorgarPuntosJob)
    end

    it "desmarcar o anotar una novedad no encola nada" do
      expect {
        post registros_entrenamiento_path,
             params: { fecha: Date.current.iso8601, indice: 0, hecho: "false", nombre: "Sentadilla" }
        post registros_entrenamiento_path,
             params: { fecha: Date.current.iso8601, novedad: "molestia en rodilla" }
      }.not_to have_enqueued_job(OtorgarPuntosJob)
    end
  end
end
