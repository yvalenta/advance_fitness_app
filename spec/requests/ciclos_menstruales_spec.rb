require "rails_helper"

# Fase 14.15 — el diseño de privacidad ES el entregable: además del CRUD con
# y sin consentimiento, aquí se blinda que la card "Mi ciclo" jamás llegue a
# ojos del staff (ni en /progreso ni en admin/users/:id).
RSpec.describe "Ciclo menstrual", type: :request do
  before { host! "advance-fitness.example.com" }

  let(:tenant) { tenants(:advance_fitness) }
  let(:usuaria) do
    User.create!(email_address: "usuaria-ciclo@x.com", password: "clave1234",
                 rol: "miembro", tenant: tenant, nombre: "Usuaria Ciclo", sexo: "F")
  end
  let(:admin) { users(:admin) }

  def consentir(user = usuaria, tipo: "ciclo_menstrual", version: "ciclo-v1")
    user.consentimientos.create!(tipo:, accion: "otorgado", version_texto: version)
  end

  def crear_ciclo(user = usuaria, inicio = Date.current)
    CicloMenstrual.create!(user:, creado_por: user, fecha_inicio: inicio)
  end

  describe "POST /ciclos_menstruales" do
    it "sin consentimiento vigente NO captura ni un dato (Pundit rechaza)" do
      sign_in_as usuaria
      expect do
        post ciclos_menstruales_path, params: { ciclo_menstrual: { fecha_inicio: Date.current } }
      end.not_to change(CicloMenstrual, :count)
      expect(response).to redirect_to(root_path) # rescue de Pundit::NotAuthorizedError
    end

    it "con consentimiento crea el registro con la propia usuaria como autora" do
      consentir
      sign_in_as usuaria
      expect do
        post ciclos_menstruales_path,
             params: { ciclo_menstrual: { fecha_inicio: Date.current, duracion_sangrado_dias: 4 } }
      end.to change(usuaria.ciclos_menstruales, :count).by(1)
      registro = usuaria.ciclos_menstruales.last
      expect(registro.creado_por).to eq(usuaria)
      expect(registro.duracion_sangrado_dias).to eq(4)
      expect(response).to redirect_to(progreso_path)
    end

    it "rechaza una fecha futura con alerta, sin crear nada" do
      consentir
      sign_in_as usuaria
      expect do
        post ciclos_menstruales_path, params: { ciclo_menstrual: { fecha_inicio: Date.current + 1 } }
      end.not_to change(CicloMenstrual, :count)
      expect(flash[:alert]).to match(/futura/)
    end

    it "no duplica el mismo inicio" do
      consentir
      crear_ciclo
      sign_in_as usuaria
      expect do
        post ciclos_menstruales_path, params: { ciclo_menstrual: { fecha_inicio: Date.current } }
      end.not_to change(CicloMenstrual, :count)
      expect(flash[:alert]).to be_present
    end
  end

  describe "DELETE /ciclos_menstruales/:id" do
    it "borra un registro propio, incluso con el consentimiento ya revocado" do
      consentir
      registro = crear_ciclo
      usuaria.consentimientos.create!(tipo: "ciclo_menstrual", accion: "revocado",
                                      version_texto: "ciclo-v1")
      sign_in_as usuaria
      expect { delete ciclo_menstrual_path(registro) }.to change(CicloMenstrual, :count).by(-1)
    end

    it "un id ajeno responde 404 — ni siquiera para un admin del mismo tenant" do
      consentir
      registro = crear_ciclo
      sign_in_as admin
      expect { delete ciclo_menstrual_path(registro) }.not_to change(CicloMenstrual, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "consentimiento (POST / DELETE /consentimiento_ciclo)" do
    it "POST otorga ciclo_menstrual con el texto versionado ciclo-v1" do
      sign_in_as usuaria
      expect { post consentimiento_ciclo_path }.to change(Consentimiento, :count).by(1)
      fila = usuaria.consentimientos.last
      expect(fila).to have_attributes(tipo: "ciclo_menstrual", accion: "otorgado",
                                      version_texto: "ciclo-v1")
      expect(Consentimiento.vigente?(usuaria, "ciclo_menstrual")).to be(true)
    end

    it "POST con el opt-in de IA marcado otorga TAMBIÉN ciclo_menstrual_ia (separado)" do
      sign_in_as usuaria
      expect do
        post consentimiento_ciclo_path, params: { consentimiento_ciclo: { acepta_ia: "1" } }
      end.to change(Consentimiento, :count).by(2)
      expect(Consentimiento.vigente?(usuaria, "ciclo_menstrual_ia")).to be(true)
      expect(usuaria.consentimientos.find_by(tipo: "ciclo_menstrual_ia").version_texto)
        .to eq("ciclo-ia-v1")
    end

    it "POST ambito=ia exige el consentimiento base vigente" do
      sign_in_as usuaria
      expect do
        post consentimiento_ciclo_path(ambito: "ia")
      end.not_to change(Consentimiento, :count)
    end

    it "DELETE revoca y BORRA los ciclos en una sola operación, dejando rastro" do
      consentir
      crear_ciclo(usuaria, Date.current - 28)
      crear_ciclo(usuaria, Date.current)
      sign_in_as usuaria

      delete consentimiento_ciclo_path

      expect(usuaria.ciclos_menstruales.count).to eq(0)
      expect(Consentimiento.vigente?(usuaria, "ciclo_menstrual")).to be(false)
      expect(usuaria.consentimientos.where(tipo: "ciclo_menstrual").count).to eq(2) # otorgado + revocado
    end

    it "DELETE con conservar_datos=1 revoca pero conserva los registros" do
      consentir
      crear_ciclo
      sign_in_as usuaria

      delete consentimiento_ciclo_path, params: { conservar_datos: "1" }

      expect(usuaria.ciclos_menstruales.count).to eq(1)
      expect(Consentimiento.vigente?(usuaria, "ciclo_menstrual")).to be(false)
    end

    it "DELETE ambito=ia retira solo el permiso de IA, sin tocar datos ni el consentimiento base" do
      consentir
      consentir(usuaria, tipo: "ciclo_menstrual_ia", version: "ciclo-ia-v1")
      crear_ciclo
      sign_in_as usuaria

      delete consentimiento_ciclo_path(ambito: "ia")

      expect(Consentimiento.vigente?(usuaria, "ciclo_menstrual_ia")).to be(false)
      expect(Consentimiento.vigente?(usuaria, "ciclo_menstrual")).to be(true)
      expect(usuaria.ciclos_menstruales.count).to eq(1)
    end
  end

  describe "card en /progreso (visibilidad estricta)" do
    it "usuaria con consentimiento ve la card completa con fase y form" do
      consentir
      crear_ciclo
      sign_in_as usuaria
      get progreso_path
      expect(response.body).to include('id="mi_ciclo"')
      expect(response.body).to include("Fase: Menstrual")
      expect(response.body).to include("Registrar inicio de ciclo")
    end

    it "usuaria (sexo F) sin consentimiento ve la invitación con el texto ciclo-v1" do
      sign_in_as usuaria
      get progreso_path
      expect(response.body).to include('id="invitacion_ciclo"')
      expect(response.body).to include("ciclo-v1")
      expect(response.body).not_to include('id="mi_ciclo"')
    end

    it "sin sexo declarado la invitación solo se ofrece tras un link discreto" do
      sign_in_as users(:two) # fixture sin sexo
      get progreso_path
      expect(response.body).to include("¿Llevas tu ciclo menstrual?")
      expect(response.body).to include('id="invitacion_ciclo"') # plegada en <details>
      expect(response.body).not_to include('id="mi_ciclo"')
    end

    # BLINDAJE anti-staff en la capa de vistas: la pantalla donde el staff ve
    # el progreso AJENO es admin/users/:id (reutiliza los parciales shared/*
    # con el @progreso del miembro). Ahí no debe llegar NI RASTRO de la card.
    it "el staff que mira el progreso ajeno (admin/users/:id) no recibe ni rastro del ciclo" do
      consentir
      crear_ciclo
      sign_in_as admin
      get admin_user_path(usuaria)
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("mi_ciclo")
      expect(response.body).not_to include("Registrar inicio de ciclo")
      expect(response.body).not_to include("invitacion_ciclo")
    end

    it "en el /progreso del propio staff la card sale solo con SUS datos (nunca los de otra persona)" do
      consentir # la usuaria consintió y tiene datos…
      crear_ciclo
      sign_in_as admin # …pero el admin entra a SU progreso
      get progreso_path
      expect(response.body).not_to include('id="mi_ciclo"')
    end
  end
end
