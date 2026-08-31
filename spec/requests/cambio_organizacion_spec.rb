require "rails_helper"

# El pase firmado del cambio de organización (tarea 2026-08-31): specs de
# ABUSO ante todo — el canje es una puerta de entrada sin sesión, así que
# cada forma de pase malo (vencido, reusado, purpose ajeno, sin puesto) debe
# morir en el MISMO redirect al login sin crear sesión ni mover la cache.
#
# Nota de fidelidad: rack-test manda las cookies a TODOS los hosts (no
# simula host-only), así que antes de canjear en el destino se borra la
# cookie de sesión a mano — como le pasa al navegador real, donde la cookie
# del origen jamás viaja al otro subdominio.
RSpec.describe "Cambio de organización con pase firmado", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:usuario) { users(:one) }
  let(:megaplex) { tenants(:megaplex) }

  def con_puesto_en_megaplex(user = usuario, rol: "miembro")
    user.puestos.create!(tenant: megaplex, rol: rol)
  end

  def emitir_pase_desde_origen
    host! "advance-fitness.example.com"
    sign_in_as usuario
    post cambio_organizacion_path, params: { tenant_id: megaplex.id }
    Rack::Utils.parse_query(URI(response.location).query)["token"]
  end

  def canjear_en_destino(token, **headers)
    host! "megaplex.example.com"
    cookies.delete("session_id") # host-only: la cookie del origen no viaja
    get cambio_organizacion_path, params: { token: token }, headers: headers
  end

  describe "#create (origen)" do
    it "con puesto en el destino emite el pase y redirige al subdominio destino" do
      con_puesto_en_megaplex
      token = emitir_pase_desde_origen

      expect(response.location).to start_with("http://megaplex.example.com/cambio_organizacion?token=")
      # El pase resuelve al usuario con el purpose fijo — no es un signed_id genérico.
      expect(User.find_signed(token, purpose: :cambio_organizacion)).to eq(usuario)
    end

    it "sin puesto en el destino no emite pase y se queda en el origen" do
      host! "advance-fitness.example.com"
      sign_in_as usuario # solo tiene puesto en advance-fitness
      post cambio_organizacion_path, params: { tenant_id: megaplex.id }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/no tienes un puesto/i)
    end
  end

  describe "#show (destino) — abuso" do
    # 16 s > VALIDEZ_DEL_PASE (15 s, tarea 2026-08-31): este ejemplo FIJA la
    # ventana — si alguien la vuelve a subir, el token de 16 s canjearía y
    # esto falla.
    it "token vencido (16s) es rechazado sin crear sesión" do
      con_puesto_en_megaplex
      token = emitir_pase_desde_origen
      sesiones_antes = Session.count

      travel 16.seconds do
        canjear_en_destino(token)
      end

      expect(response).to redirect_to(new_session_path)
      expect(Session.count).to eq(sesiones_antes)
      expect(CambioOrganizacion.where(user: usuario)).to be_empty
    end

    # El otro filo de la ventana: 14 s todavía canjea. Sin esto, bajar la
    # validez a "casi cero" pasaría verde aunque rompiera el flujo real.
    it "token de 14s sigue vivo: el redirect lento pero honesto entra" do
      con_puesto_en_megaplex
      token = emitir_pase_desde_origen

      travel 14.seconds do
        canjear_en_destino(token)
      end

      expect(response).to redirect_to(root_path)
      expect(CambioOrganizacion.where(user: usuario).count).to eq(1)
    end

    it "token REUSADO es rechazado y el log lo muestra UNA sola vez" do
      con_puesto_en_megaplex
      token = emitir_pase_desde_origen

      canjear_en_destino(token)
      expect(response).to redirect_to(root_path) # primer canje: pasa

      sesiones_tras_primer_canje = Session.count
      canjear_en_destino(token)

      expect(response).to redirect_to(new_session_path)
      expect(Session.count).to eq(sesiones_tras_primer_canje)
      digest = Digest::SHA256.hexdigest(token)
      expect(CambioOrganizacion.where(token_digest: digest).count).to eq(1)
    end

    it "token de OTRO purpose es rechazado sin crear sesión" do
      con_puesto_en_megaplex
      token_ajeno = usuario.signed_id(purpose: :password_reset,
                                      expires_in: CambiosOrganizacionController::VALIDEZ_DEL_PASE)
      sesiones_antes = Session.count

      canjear_en_destino(token_ajeno)

      expect(response).to redirect_to(new_session_path)
      expect(Session.count).to eq(sesiones_antes)
      expect(CambioOrganizacion.where(user: usuario)).to be_empty
    end

    it "token válido pero SIN puesto en el destino es rechazado sin sesión y sin mover la cache" do
      # users(:two) solo pertenece a advance-fitness: un pase legítimo suyo
      # no le abre la puerta de un gimnasio donde no tiene puesto.
      token = users(:two).signed_id(purpose: :cambio_organizacion,
                                    expires_in: CambiosOrganizacionController::VALIDEZ_DEL_PASE)
      sesiones_antes = Session.count

      canjear_en_destino(token)

      expect(response).to redirect_to(new_session_path)
      expect(Session.count).to eq(sesiones_antes)
      expect(CambioOrganizacion.where(user: users(:two))).to be_empty
      expect(users(:two).reload.tenant).to eq(tenants(:advance_fitness))
    end
  end

  describe "#show (destino) — happy path" do
    it "abre sesión nueva en el destino, estaciona la cache y deja el log con ip y tenants" do
      con_puesto_en_megaplex(usuario, rol: "entrenador")
      token = emitir_pase_desde_origen
      sesiones_antes = Session.where(user: usuario).count

      canjear_en_destino(token, "User-Agent" => "RSpec")

      expect(response).to redirect_to(root_path)
      # Sesión NUEVA del subdominio destino
      expect(Session.where(user: usuario).count).to eq(sesiones_antes + 1)
      # Cache estacionada: tenant Y rol copiados DEL puesto destino
      usuario.reload
      expect(usuario.tenant).to eq(megaplex)
      expect(usuario.rol).to eq("entrenador")
      # Log append-only completo
      fila = CambioOrganizacion.find_by!(user: usuario)
      expect(fila.de_tenant).to eq(tenants(:advance_fitness))
      expect(fila.a_tenant).to eq(megaplex)
      expect(fila.ip).to be_present
      expect(fila.user_agent).to eq("RSpec")
      expect(fila.token_digest).to eq(Digest::SHA256.hexdigest(token))
      # Y la sesión sirve: el siguiente request en el destino entra directo
      get root_path
      expect(response).to have_http_status(:success)
    end

    it "la cookie de sesión JAMÁS lleva atributo domain (host-only, nunca .ynt.codes)" do
      con_puesto_en_megaplex
      token = emitir_pase_desde_origen
      canjear_en_destino(token)

      set_cookie = Array(response.headers["Set-Cookie"]).flat_map { |v| v.split("\n") }
      linea_session = set_cookie.find { |linea| linea.start_with?("session_id=") }
      expect(linea_session).to be_present
      expect(linea_session.downcase).not_to include("domain=")
    end
  end

  describe "auditoría del superadmin" do
    let(:superadmin) do
      User.create!(email_address: "sa@x.com", password: "clave1234", rol: "superadmin", nombre: "SA")
    end

    it "entrar a un tenant ajeno escribe en cambios_organizacion (sin pase) y no duplica por request" do
      host! "megaplex.example.com"
      sign_in_as superadmin
      get root_path
      expect(response).to have_http_status(:success)

      fila = CambioOrganizacion.find_by!(user: superadmin)
      expect(fila.a_tenant).to eq(megaplex)
      expect(fila.de_tenant).to be_nil
      expect(fila.token_digest).to be_nil
      expect(fila.ip).to be_present

      get root_path
      expect(CambioOrganizacion.where(user: superadmin).count).to eq(1)
    end

    it "el portal comercial no es un tenant: entrar ahí no escribe nada" do
      host! "comercial.example.com"
      sign_in_as superadmin
      get superadmin_tenants_path
      expect(response).to have_http_status(:success)
      expect(CambioOrganizacion.where(user: superadmin)).to be_empty
    end
  end
end
