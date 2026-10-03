require "rails_helper"

RSpec.describe PerfilJuego, type: :model do
  let(:user) { users(:one) }

  it "hereda el tenant del user (TenantDesnormalizado) sin que nadie lo pase" do
    perfil = PerfilJuego.create!(user: user)
    expect(perfil.tenant_id).to eq user.tenant_id
  end

  it "rechaza un tenant_id incoherente con el del user (mass-assignment)" do
    otro_tenant = tenants(:megaplex)
    perfil = PerfilJuego.new(user: user, tenant_id: otro_tenant.id)
    expect(perfil).not_to be_valid
    expect(perfil.errors[:tenant_id]).to be_present
  end

  it "un perfil por user (validación + índice único)" do
    PerfilJuego.create!(user: user)
    expect(PerfilJuego.new(user: user)).not_to be_valid
  end

  it "arranca en cero: nivel 1, sin puntos, sin racha, oculto de la tabla" do
    perfil = PerfilJuego.create!(user: user)
    expect(perfil.puntos_total).to eq 0
    expect(perfil.nivel).to eq 1
    expect(perfil.racha_actual).to eq 0
    expect(perfil.visible_en_tabla).to be false
  end

  it "nivel_para: cuadrática documentada — 0-99 → 1, 100 → 2, 400 → 3, 900 → 4" do
    expect(PerfilJuego.nivel_para(0)).to eq 1
    expect(PerfilJuego.nivel_para(99)).to eq 1
    expect(PerfilJuego.nivel_para(100)).to eq 2
    expect(PerfilJuego.nivel_para(399)).to eq 2
    expect(PerfilJuego.nivel_para(400)).to eq 3
    expect(PerfilJuego.nivel_para(900)).to eq 4
    expect(PerfilJuego.nivel_para(-50)).to eq 1 # ajustes manuales en rojo no rompen
  end

  it "PerfilJuego.para es find-or-create idempotente" do
    a = PerfilJuego.para(user)
    b = PerfilJuego.para(user)
    expect(a.id).to eq b.id
    expect(PerfilJuego.where(user: user).count).to eq 1
  end

  # H2 (refutación ronda 1): el perfil NACÍA con el tenant viejo si se creaba
  # con una cuenta cargada antes de que commiteara el canje del pase (lo que
  # hacen OtorgarPuntosJob y TablaPosiciones#participar en vuelo): el callback
  # de User ya había corrido sin ver perfil, la validación comparaba contra la
  # cuenta VIEJA en memoria, y nada lo reparaba — todo update! posterior
  # reventaba. Ahora la creación lee el tenant fresco de la cuenta (con
  # `FOR SHARE`, que serializa contra la mudanza) y se niega: fail-closed, igual
  # que la validación de siempre cuando el perfil ya existe.
  describe "con la cuenta cargada ANTES de que se mudara (carrera con el canje del pase)" do
    let(:megaplex) { tenants(:megaplex) }

    before { user.puestos.create!(tenant: megaplex, rol: "miembro") }

    # El canje commitea por otra vía (otra request/conexión): la cuenta que
    # tiene en memoria el job o el controller sigue con el tenant viejo.
    def cuenta_cargada_antes_de_la_mudanza
      cargada = User.find(user.id)
      User.find(user.id).estacionar_en!(megaplex)
      cargada
    end

    it "no nace un perfil con el tenant viejo: RecordInvalid y ninguna fila" do
      cargada = cuenta_cargada_antes_de_la_mudanza

      expect { PerfilJuego.para(cargada) }
        .to raise_error(ActiveRecord::RecordInvalid, /Tenant debe coincidir/)
      expect(PerfilJuego.where(user_id: user.id)).to be_empty
    end

    it "no deja el motor bloqueado: con la cuenta fresca el perfil nace en el tenant nuevo" do
      cuenta_cargada_antes_de_la_mudanza

      expect { Juego::Racha.actualizar!(User.find(user.id), fecha: Date.current) }.not_to raise_error
      expect(PerfilJuego.find_by(user_id: user.id).tenant_id).to eq(megaplex.id)
    end

    it "tampoco se cuela con un tenant_id explícito: ni el viejo ni el nuevo con la cuenta cargada vieja" do
      cargada = cuenta_cargada_antes_de_la_mudanza

      expect { PerfilJuego.create!(user: cargada, tenant_id: megaplex.id) }
        .to raise_error(ActiveRecord::RecordInvalid, /Tenant debe coincidir/)
      expect(PerfilJuego.where(user_id: user.id)).to be_empty
    end

    it "control: con el perfil YA existente, la validación de siempre corta al update! de la cuenta vieja" do
      PerfilJuego.para(user)
      perfil = PerfilJuego.para(User.find(user.id)) # participar lo carga: la cuenta aún en AF
      User.find(user.id).estacionar_en!(megaplex)

      expect { perfil.update!(visible_en_tabla: true) }
        .to raise_error(ActiveRecord::RecordInvalid, /Tenant debe coincidir/)
    end

    # F1 (refutación ronda 2): el candado de arriba cubría solo la CREACIÓN. Un
    # perfil recién creado con la cuenta cargada en memoria (participar lo
    # hace en :46) nace bien en el tenant viejo, el canje commitea, el callback
    # de User lo muda y apaga el flag — y el `update!(visible_en_tabla: true)`
    # siguiente comparaba la cuenta vieja con el tenant viejo, pasaba, y como
    # Rails escribe solo las columnas cambiadas la fila quedaba EN el tenant
    # nuevo y VISIBLE, con un consentimiento dado en la pantalla del viejo.
    # Encender el flag relee el tenant fresco de la cuenta, igual que crear.
    it "F1: el perfil recién creado con la cuenta vieja no se enciende en el tenant nuevo" do
      perfil = PerfilJuego.para(User.find(user.id)) # nace en AF, con la cuenta cargada en memoria
      expect(perfil.tenant_id).to eq(user.tenant_id)
      User.find(user.id).estacionar_en!(megaplex)   # el canje commitea; el callback lo muda y apaga

      expect { perfil.update!(visible_en_tabla: true, apodo: nil) }
        .to raise_error(ActiveRecord::RecordInvalid, /Tenant debe coincidir/)
      expect(PerfilJuego.find(perfil.id))
        .to have_attributes(tenant_id: megaplex.id, visible_en_tabla: false)
      expect(PerfilJuego.where(tenant_id: megaplex.id, visible_en_tabla: true)).to be_empty
    end

    it "F1: con la cuenta al día, encender el flag sigue funcionando (el candado no estorba)" do
      perfil = PerfilJuego.para(User.find(user.id))

      expect { perfil.update!(visible_en_tabla: true) }.not_to raise_error
      expect(perfil.reload.visible_en_tabla).to be true
    end

    it "F1: apagar nunca se bloquea — retirarse con la cuenta vieja deja la fila apagada" do
      perfil = PerfilJuego.para(User.find(user.id))
      perfil.update!(visible_en_tabla: true)
      User.find(user.id).estacionar_en!(megaplex)

      expect { perfil.update!(visible_en_tabla: false) }.not_to raise_error
      expect(PerfilJuego.find(perfil.id).visible_en_tabla).to be false
    end
  end

  # El motor entero escribe el perfil con `update!` (Racha, Otorgador,
  # Recalculador): tras un cambio de gimnasio ninguno puede reventar. Cada uno
  # arranca de un perfil creado ANTES del cambio — el orden real, y el que
  # dejaba el tenant viejo pegado.
  describe "tras cambiar de gimnasio (el juego es de la persona)" do
    before do
      PerfilJuego.para(user)
      user.puestos.create!(tenant: tenants(:megaplex), rol: "miembro")
      user.estacionar_en!(tenants(:megaplex))
      user.reload
    end

    it "Juego::Racha registra el día sin RecordInvalid" do
      perfil = Juego::Racha.actualizar!(user, fecha: Date.current)

      expect(perfil.racha_actual).to eq 1
      expect(perfil.tenant_id).to eq tenants(:megaplex).id
    end

    it "Juego::Otorgador suma los puntos sin RecordInvalid" do
      Juego::Otorgador.otorgar!(user, tipo: "checkin", fecha: Date.current)

      expect(user.reload.perfil_juego.puntos_total).to eq Juego::Otorgador::PUNTOS["checkin"]
    end

    it "Juego::Recalculador reconstruye la proyección sin RecordInvalid" do
      expect { Juego::Recalculador.para(user) }.not_to raise_error
    end
  end
end
