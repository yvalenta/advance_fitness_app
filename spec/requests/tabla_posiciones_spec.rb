require "rails_helper"

# Fase 14.14 — la tabla de posiciones es la vista más sensible del producto:
# lista datos ENTRE miembros. Este spec fija el contrato completo: opt-in
# explícito y auditable (Consentimiento ranking-v1 + visible_en_tabla en una
# transacción), reciprocidad (quien no participa no ve un solo nombre real),
# la fila propia con posición real fuera del top 50, desempate por antigüedad
# y que NADIE — ni el staff — activa la visibilidad de otro.
RSpec.describe "Tabla de posiciones", type: :request do
  before { host! "advance-fitness.example.com" }

  let(:miembro) { users(:one) }
  let(:otro) { users(:two) }
  let(:admin) { users(:admin) }

  def perfil_visible!(user, puntos:, apodo: nil, racha: 0)
    PerfilJuego.create!(user: user, visible_en_tabla: true, puntos_total: puntos,
                        nivel: PerfilJuego.nivel_para(puntos), apodo: apodo,
                        racha_actual: racha)
  end

  # 50 rivales por encima de `puntos` sin pagar bcrypt 50 veces: se reutiliza
  # el digest de la fixture.
  def sembrar_rivales!(cantidad, desde_puntos:)
    digest = users(:one).password_digest
    cantidad.times do |indice|
      rival = User.create!(email_address: "rival#{indice}@example.com",
                           password_digest: digest, rol: "miembro",
                           tenant: tenants(:advance_fitness), nombre: "Rival #{indice}")
      PerfilJuego.create!(user: rival, visible_en_tabla: true,
                          puntos_total: desde_puntos + indice, apodo: "Rival#{indice}")
    end
  end

  describe "GET /ranking como participante" do
    before do
      perfil_visible!(miembro, puntos: 120, apodo: "Rayo")
      perfil_visible!(otro, puntos: 480, apodo: "Tornado", racha: 6)
      sign_in_as miembro
    end

    it "muestra el podio con los participantes y marca la fila propia" do
      get ranking_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Tornado")
      expect(response.body).to include("Rayo")
      expect(response.body).to include("(tú)")
    end

    it "jamás imprime el correo de OTRO miembro (lo promete el texto del opt-in)" do
      # El propio correo sí sale en el body — en el menú de cuenta del navbar,
      # que es del usuario consigo mismo. Lo que no puede pasar es que el
      # correo de un tercero llegue por las filas del ranking.
      get ranking_path

      expect(response.body).not_to include("two@example.com")
    end
  end

  describe "GET /ranking fuera del top 50" do
    it "muestra la fila propia fija con la posición real" do
      perfil_visible!(miembro, puntos: 10, apodo: "Rayo")
      sembrar_rivales!(50, desde_puntos: 1_000)
      sign_in_as miembro

      get ranking_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("#51")
      expect(response.body).to include("Rayo")
    end
  end

  describe "empates en puntos" do
    it "queda arriba quien llegó primero al marcador (updated_at asc)" do
      # 3 rivales llenan el podio: el empate se resuelve en la lista plana,
      # donde el orden del HTML es el orden del ranking.
      sembrar_rivales!(3, desde_puntos: 1_000)
      veterano = perfil_visible!(miembro, puntos: 300, apodo: "Veterano")
      veterano.update_column(:updated_at, 2.days.ago)
      perfil_visible!(otro, puntos: 300, apodo: "Reciente")
      sign_in_as miembro

      get ranking_path

      expect(response.body.index("Veterano")).to be < response.body.index("Reciente")
    end
  end

  describe "GET /ranking sin participar" do
    it "no muestra ningún dato real y ofrece el opt-in (reciprocidad)" do
      perfil_visible!(otro, puntos: 480, apodo: "Tornado")
      # Tener perfil con visible_en_tabla en false tampoco cuenta como participar
      PerfilJuego.create!(user: miembro)
      sign_in_as miembro

      get ranking_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Tornado")
      expect(response.body).not_to include("Usuario Dos")
      expect(response.body).to include("Quiero aparecer en la tabla")
    end
  end

  describe "roles globales" do
    it "superadmin recibe un redirect elegante: el ranking es de los miembros" do
      superadmin = User.create!(email_address: "root@ynt.codes", nombre: "Root",
                                password_digest: users(:admin).password_digest,
                                rol: "superadmin")
      sign_in_as superadmin

      get ranking_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /ranking/participacion" do
    it "crea el consentimiento ranking-v1 y activa la visibilidad" do
      sign_in_as miembro

      expect {
        post ranking_participacion_path, params: { perfil_juego: { apodo: "Rayo" } }
      }.to change {
        Consentimiento.where(user: miembro, tipo: "tabla_posiciones", accion: "otorgado").count
      }.by(1)

      consentimiento = Consentimiento.where(user: miembro).order(:created_at, :id).last
      expect(consentimiento.version_texto).to eq "ranking-v1"
      expect(Consentimiento.vigente?(miembro, "tabla_posiciones")).to be true

      perfil = miembro.reload.perfil_juego
      expect(perfil.visible_en_tabla).to be true
      expect(perfil.apodo).to eq "Rayo"
    end

    it "repetir el POST solo edita el apodo — no ensucia el registro append-only" do
      sign_in_as miembro
      post ranking_participacion_path, params: { perfil_juego: { apodo: "Rayo" } }

      expect {
        post ranking_participacion_path, params: { perfil_juego: { apodo: "Trueno" } }
      }.not_to change { Consentimiento.count }

      expect(miembro.reload.perfil_juego.apodo).to eq "Trueno"
    end

    it "un staff NO puede activar la visibilidad de otro: el endpoint solo opera el perfil propio" do
      perfil_ajeno = PerfilJuego.create!(user: miembro)
      sign_in_as admin

      post ranking_participacion_path,
           params: { user_id: miembro.id, perfil_juego: { apodo: "Forzado" } }

      expect(perfil_ajeno.reload.visible_en_tabla).to be false
      expect(perfil_ajeno.apodo).to be_nil
      expect(Consentimiento.where(user: miembro).count).to eq 0
      # Y aunque un endpoint futuro aceptara el perfil ajeno, la policy lo niega:
      expect(PerfilJuegoPolicy.new(admin, perfil_ajeno).update?).to be false
    end
  end

  describe "DELETE /ranking/participacion" do
    it "revoca el consentimiento y oculta el perfil, dejando rastro de ambos" do
      sign_in_as miembro
      post ranking_participacion_path, params: { perfil_juego: { apodo: "Rayo" } }

      expect {
        delete ranking_participacion_path
      }.to change { Consentimiento.where(user: miembro, accion: "revocado").count }.by(1)

      expect(miembro.reload.perfil_juego.visible_en_tabla).to be false
      expect(Consentimiento.vigente?(miembro, "tabla_posiciones")).to be false
      # El otorgamiento original sigue ahí: historial append-only, jamás se borra
      expect(Consentimiento.where(user: miembro, accion: "otorgado").count).to eq 1
    end

    it "sin participación previa es un no-op amable" do
      sign_in_as miembro

      expect { delete ranking_participacion_path }.not_to change { Consentimiento.count }

      expect(response).to redirect_to(ranking_path)
    end
  end
end
