require "rails_helper"
require Rails.root.join("db/migrate/20261003000000_resincronizar_tenant_de_perfiles_juego")

# Migración de datos (Nota 29): los perfiles que quedaron con el tenant viejo
# tras un cambio de gimnasio vuelven a coincidir con su cuenta, sin tocar a los
# demás y con la misma regla de privacidad que el código vivo.
RSpec.describe ResincronizarTenantDePerfilesJuego do
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
  # perfil no. `update_columns` lo reproduce saltando el callback nuevo.
  before do
    PerfilJuego.create!(user: movido, visible_en_tabla: true, puntos_total: 300, apodo: "Tornado")
    PerfilJuego.create!(user: quieto, visible_en_tabla: true, puntos_total: 120, apodo: "Rayo")
    [ movido, quieto ].each do |user|
      otorgar!(user, "tabla_posiciones")
      otorgar!(user, "logros_comunidad")
    end
    movido.update_columns(tenant_id: megaplex.id)
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
end
