require "rails_helper"
require Rails.root.join("db/migrate/20261003000000_resincronizar_tenant_de_perfiles_juego")

# Migración de datos (Nota 29): los perfiles que quedaron con el tenant viejo
# tras un cambio de gimnasio vuelven a coincidir con su cuenta, sin tocar a los
# demás y con la misma regla de privacidad que el código vivo. La revocación de
# los opt-in sale de `cambios_organizacion` (quién se mudó y cuándo), no del
# perfil: hay cuentas que se mudaron sin perfil, o cuyo perfil nació ya en el
# gimnasio nuevo, y siguen exponiendo el opt-in del viejo.
RSpec.describe ResincronizarTenantDePerfilesJuego do
  include ActiveSupport::Testing::TimeHelpers

  after { travel_back }

  let(:af) { tenants(:advance_fitness) }
  let(:megaplex) { tenants(:megaplex) }
  let(:movido) { users(:two) }   # cambió de gimnasio con el código anterior
  let(:quieto) { users(:one) }   # nunca se movió

  def migrar!(direccion = :up)
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(direccion) }
  end

  def otorgar!(user, tipo)
    Consentimiento.create!(user: user, tipo: tipo, accion: "otorgado", version_texto: "v1")
  end

  # El estado que dejaba el código anterior: la cache de la cuenta se mueve y el
  # perfil no (`update_columns` salta el callback nuevo), y el embudo escribe la
  # fila de `cambios_organizacion` — la fuente de quién se mudó y cuándo (con
  # pase, `token_digest`, y de un tenant a otro).
  def mudar_con_el_codigo_anterior!(user, de:, a:)
    user.update_columns(tenant_id: a.id)
    CambioOrganizacion.create!(user: user, de_tenant: de, a_tenant: a,
                               token_digest: SecureRandom.hex(16))
  end

  before do
    PerfilJuego.create!(user: movido, visible_en_tabla: true, puntos_total: 300, apodo: "Tornado")
    PerfilJuego.create!(user: quieto, visible_en_tabla: true, puntos_total: 120, apodo: "Rayo")
    [ movido, quieto ].each do |user|
      otorgar!(user, "tabla_posiciones")
      otorgar!(user, "logros_comunidad")
    end
    travel 1.minute
    mudar_con_el_codigo_anterior!(movido, de: af, a: megaplex)
    travel 1.minute
  end

  it "el desfase es real antes de migrar: el perfil revienta en cualquier update!" do
    expect { movido.perfil_juego.update!(racha_actual: 1) }
      .to raise_error(ActiveRecord::RecordInvalid, /Tenant debe coincidir/)
  end

  it "re-sincroniza el tenant del perfil desfasado y deja de reventar" do
    migrar!

    perfil = movido.reload.perfil_juego
    expect(perfil.tenant_id).to eq(megaplex.id)
    expect { perfil.update!(racha_actual: 1) }.not_to raise_error
  end

  it "conserva lo de la persona (puntos, apodo) y apaga la visibilidad en el re-sincronizado" do
    migrar!

    expect(movido.reload.perfil_juego).to have_attributes(puntos_total: 300, apodo: "Tornado",
                                                           visible_en_tabla: false)
  end

  it "revoca con rastro los consentimientos de visibilidad del re-sincronizado" do
    migrar!

    expect(Consentimiento.vigente?(movido, "tabla_posiciones")).to be(false)
    expect(Consentimiento.vigente?(movido, "logros_comunidad")).to be(false)
    revocados = Consentimiento.where(user: movido, accion: "revocado")
    expect(revocados.pluck(:tipo)).to contain_exactly("tabla_posiciones", "logros_comunidad")
    expect(revocados.pluck(:version_texto).uniq).to eq([ "cambio-de-gimnasio" ])
  end

  it "no toca a los perfiles que ya coinciden con su cuenta (ni su visibilidad ni sus consentimientos)" do
    migrar!

    expect(quieto.reload.perfil_juego.visible_en_tabla).to be(true)
    expect(Consentimiento.vigente?(quieto, "tabla_posiciones")).to be(true)
    expect(Consentimiento.vigente?(quieto, "logros_comunidad")).to be(true)
  end

  it "es idempotente: correrla dos veces no repite revocaciones" do
    migrar!

    expect { migrar! }.not_to change(Consentimiento, :count)
  end

  it "down es un no-op (el tenant viejo no se repone)" do
    migrar!

    expect { migrar!(:down) }.not_to change { movido.reload.perfil_juego.tenant_id }
  end

  # H1 (refutación ronda 1): el JOIN por perfil desfasado dejaba fuera a quien
  # se mudó sin perfil o cuyo perfil nació ya en el gimnasio nuevo: seguían en
  # el muro del nuevo con el `logros_comunidad` del viejo.
  describe "cuentas movidas que el perfil desfasado no delata" do
    # `quieto` ya optó (before) en el gimnasio donde estaba parado.
    def mudarse_sin_perfil!
      quieto.perfil_juego.destroy!
      mudar_con_el_codigo_anterior!(quieto, de: af, a: megaplex)
    end

    it "movida SIN perfil: el opt-in del muro del gimnasio viejo queda revocado, con rastro" do
      mudarse_sin_perfil!

      migrar!

      expect(Consentimiento.vigente?(quieto, "logros_comunidad")).to be(false)
      ultimo = Consentimiento.where(user: quieto, tipo: "logros_comunidad").order(:created_at, :id).last
      expect(ultimo).to have_attributes(accion: "revocado", version_texto: "cambio-de-gimnasio")
    end

    it "movida SIN perfil: no aparece en el muro del gimnasio nuevo sin consentir ahí" do
      quieto.puestos.create!(tenant: megaplex, rol: "miembro")
      logro = Logro.create!(codigo: "ref-h1", nombre: "Primera sesión", puntos: 20, categoria: "constancia")
      LogroObtenido.create!(user: quieto, logro: logro, obtenido_en: Time.current)
      mudarse_sin_perfil!
      expect(Comunidad::Muro.celebraciones(megaplex)).not_to be_empty # el hueco es real antes de migrar

      migrar!

      expect(Comunidad::Muro.celebraciones(megaplex)).to be_empty
    end

    it "cuyo perfil nació DESPUÉS de mudarse (el tenant ya coincide): el mismo opt-in también se revoca" do
      mudarse_sin_perfil!
      PerfilJuego.create!(user: quieto.reload)

      migrar!

      expect(Consentimiento.vigente?(quieto, "logros_comunidad")).to be(false)
    end

    it "volvió al gimnasio donde dio el opt-in del ranking (el perfil ya coincide): sale de la tabla" do
      # A → B → A con el código anterior: el perfil no queda desfasado al final,
      # pero el opt-in es de ANTES de la última mudanza y la tabla lee el flag.
      mudar_con_el_codigo_anterior!(quieto, de: af, a: megaplex)
      travel 1.minute
      mudar_con_el_codigo_anterior!(quieto, de: megaplex, a: af)
      travel 1.minute

      migrar!

      expect(Consentimiento.vigente?(quieto, "tabla_posiciones")).to be(false)
      expect(quieto.reload.perfil_juego.visible_en_tabla).to be(false)
      expect(PerfilJuego.where(tenant_id: af.id, visible_en_tabla: true).pluck(:user_id))
        .not_to include(quieto.id)
    end

    it "es idempotente también para estas cuentas" do
      mudarse_sin_perfil!
      migrar!

      expect { migrar! }.not_to change(Consentimiento, :count)
    end

    it "una fila de auditoría sin pase (superadmin entra a un tenant) NO es una mudanza" do
      CambioOrganizacion.create!(user: quieto, de_tenant: nil, a_tenant: megaplex)

      migrar!

      expect(Consentimiento.vigente?(quieto, "tabla_posiciones")).to be(true)
      expect(Consentimiento.vigente?(quieto, "logros_comunidad")).to be(true)
      expect(quieto.reload.perfil_juego.visible_en_tabla).to be(true)
    end

    it "un pase canjeado dentro del mismo gimnasio (de == a) NO es una mudanza" do
      CambioOrganizacion.create!(user: quieto, de_tenant: af, a_tenant: af,
                                 token_digest: SecureRandom.hex(16))

      migrar!

      expect(Consentimiento.vigente?(quieto, "logros_comunidad")).to be(true)
      expect(quieto.reload.perfil_juego.visible_en_tabla).to be(true)
    end
  end

  # H3 (refutación ronda 1): la migración revocaba el último «otorgado» sin
  # compararlo con la fecha de la mudanza, y borraba un opt-in LEGÍTIMO dado en
  # el gimnasio nuevo después de mudarse — con un rastro «cambio-de-gimnasio»
  # que mentía.
  describe "el opt-in dado DESPUÉS de mudarse es del gimnasio nuevo" do
    it "no se revoca y el rastro no miente (solo se revoca lo del gimnasio viejo)" do
      # `movido` ya se mudó (before) y opta en el muro de Megaplex DESPUÉS.
      travel 1.second
      otorgar!(movido, "logros_comunidad")

      migrar!

      expect(movido.reload.perfil_juego.tenant_id).to eq(megaplex.id) # el perfil sí se re-sincroniza
      expect(Consentimiento.vigente?(movido, "logros_comunidad")).to be(true)
      revocados = Consentimiento.where(user: movido, accion: "revocado", version_texto: "cambio-de-gimnasio")
      expect(revocados.pluck(:tipo)).to eq([ "tabla_posiciones" ]) # solo el del gimnasio viejo
    end
  end

  # Sin fila en cambios_organizacion no hay fecha que comparar: un perfil
  # desfasado de esa forma (mudanza fuera del embudo) conserva la regla vieja,
  # fail-closed — se revoca todo lo vigente.
  describe "perfil desfasado SIN fila de mudanza (no hay fecha que comparar)" do
    it "revoca todo lo vigente, fail-closed" do
      quieto.update_columns(tenant_id: megaplex.id)

      migrar!

      expect(Consentimiento.vigente?(quieto, "tabla_posiciones")).to be(false)
      expect(Consentimiento.vigente?(quieto, "logros_comunidad")).to be(false)
      expect(quieto.reload.perfil_juego).to have_attributes(tenant_id: megaplex.id, visible_en_tabla: false)
    end
  end
end
