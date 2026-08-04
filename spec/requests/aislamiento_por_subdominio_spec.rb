require "rails_helper"

# Etapa 1.4 del plan de estabilización: el aislamiento verificado sobre RUTAS
# REALES, no solo sobre los Scopes de Pundit. `spec/requests/tenant_scoping_spec.rb`
# cubre la resolución del subdominio; esto cubre las dos consecuencias que
# importan: a quién se expulsa, y qué alcanza a ver quien sí entra.
RSpec.describe "Aislamiento por subdominio", type: :request do
  let(:tenant_af) { tenants(:advance_fitness) }
  let(:tenant_mp) { tenants(:megaplex) }
  let(:admin_af) { users(:admin) }

  let(:admin_mp) do
    User.create!(email_address: "admin@megaplex.local", password: "clave1234",
                 rol: "admin", tenant: tenant_mp, nombre: "Admin Megaplex")
  end

  let(:miembro_mp) do
    User.create!(email_address: "zulema@megaplex.local", password: "clave1234",
                 rol: "miembro", tenant: tenant_mp, nombre: "Zulema Megaplex")
  end

  # Datos de dinero del tenant vecino: lo que jamás debe cruzarse (SDD §16.7).
  def sembrar_dinero_megaplex!
    membresia = Membresia.create!(user: miembro_mp, estado: "activa",
                                  fecha_inicio: Date.current,
                                  fecha_vencimiento: Date.current + 30)
    membresia.pagos.create!(monto: 777_777, metodo: "efectivo",
                            registrado_por: admin_mp, fecha_pago: Date.current,
                            periodo_inicio: Date.current, periodo_fin: Date.current + 30)
    Suscripcion.create!(user: miembro_mp, plan: planes(:free),
                        estado: "activa", fecha_inicio: Date.current)
    membresia
  end

  # `host!` ANTES de `sign_in_as` a propósito: la cookie de sesión es host-only
  # (SDD §16.6), así que un navegador real nunca mandaría la de Advance Fitness
  # al subdominio de Megaplex — simplemente vería el login. Presentar la cookie
  # del admin de AF *en el host de MP* es el escenario que
  # `verificar_pertenencia_al_tenant` sí existe para atajar: la cookie robada o
  # replicada a mano.
  describe "una sesión de otro gimnasio presentada en este subdominio" do
    it "es expulsada y la sesión queda terminada, no solo redirigida" do
      host! "megaplex.example.com"
      sign_in_as admin_af
      expect(Session.where(user_id: admin_af.id)).to be_present

      get root_path

      expect(response).to redirect_to(new_session_url)
      expect(flash[:alert]).to match(/pertenece a otro gimnasio/i)
      # `terminate_session` de verdad: si solo redirigiera, la misma cookie
      # serviría para el siguiente intento.
      expect(Session.where(user_id: admin_af.id)).to be_empty
    end

    it "tampoco alcanza una ruta de administración del otro tenant" do
      host! "megaplex.example.com"
      sign_in_as admin_af

      get admin_pagos_path

      expect(response).to redirect_to(new_session_url)
      expect(Session.where(user_id: admin_af.id)).to be_empty
    end
  end

  describe "un admin en el subdominio de SU gimnasio" do
    before do
      sembrar_dinero_megaplex!
      host! "advance-fitness.example.com"
      sign_in_as admin_af
    end

    it "no ve miembros del otro tenant en el listado de membresías" do
      get admin_membresias_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Zulema Megaplex")
    end

    it "no ve pagos del otro tenant en el historial financiero" do
      get admin_pagos_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("777.777")
      expect(response.body).not_to include("Zulema Megaplex")
    end

    it "no ve suscripciones del otro tenant" do
      get admin_suscripciones_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Zulema Megaplex")
    end
  end

  # Fase 14.14: la tabla de posiciones lista datos ENTRE miembros — el caso
  # más sensible del white-label. Ni el opt-in más entusiasta del tenant B
  # (visible_en_tabla + puntos récord) puede asomarse al /ranking del tenant A.
  describe "la tabla de posiciones en el subdominio del tenant A" do
    it "jamás lista a un miembro del tenant B, aunque esté visible y puntee más" do
      PerfilJuego.create!(user: miembro_mp, visible_en_tabla: true,
                          puntos_total: 999_999, apodo: "CampeonMegaplex")
      miembro_af = users(:one)
      PerfilJuego.create!(user: miembro_af, visible_en_tabla: true,
                          puntos_total: 10, apodo: "LocalAF")

      host! "advance-fitness.example.com"
      sign_in_as miembro_af

      get ranking_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("LocalAF") # la tabla sí se renderiza
      expect(response.body).not_to include("CampeonMegaplex")
      expect(response.body).not_to include("Zulema")
    end
  end

  # Regresión del fix 9f48ffc: el índice único de email pasó a ser compuesto
  # (email_address, tenant_id). Dos gimnasios pueden tener al mismo correo como
  # socio sin pisarse.
  describe "registro del mismo correo en dos tenants" do
    let(:credenciales) do
      { user: { nombre: "Ana Perez", email_address: "ana@correo.com",
                password: "clave1234", password_confirmation: "clave1234" } }
    end

    it "crea una cuenta independiente en cada tenant" do
      host! "advance-fitness.example.com"
      expect { post registro_path, params: credenciales }
        .to change { User.where(email_address: "ana@correo.com").count }.by(1)

      sign_out
      host! "megaplex.example.com"
      expect { post registro_path, params: credenciales }
        .to change { User.where(email_address: "ana@correo.com").count }.by(1)

      cuentas = User.where(email_address: "ana@correo.com")
      expect(cuentas.pluck(:tenant_id)).to contain_exactly(tenant_af.id, tenant_mp.id)
    end
  end
end
