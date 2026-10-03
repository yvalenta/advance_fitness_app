require "rails_helper"

RSpec.describe User, type: :model do
  it "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    expect(user.email_address).to eq("downcased@example.com")
  end

  it "VIP siempre cuenta como premium, sin importar la suscripción (Fase 12.2)" do
    expect(users(:one).premium?).to be_falsey
    users(:one).update!(vip: true)
    expect(users(:one).premium?).to be_truthy
  end

  it "requiere tenant para miembro/entrenador/admin (SDD §16.6)" do
    user = User.new(email_address: "sin@tenant.com", password: "clave1234", rol: "miembro")
    expect(user.valid?).to be_falsey
    expect(user.errors[:tenant]).to be_present
  end

  it "no requiere tenant para superadmin ni comercializador" do
    %w[superadmin comercializador].each do |rol|
      user = User.new(email_address: "#{rol}@x.com", password: "clave1234", rol: rol)
      expect(user.valid?).to be_truthy, "#{rol} debería ser válido sin tenant: #{user.errors.full_messages}"
    end
  end

  it "helpers de rol global" do
    expect(User.new(rol: "superadmin").superadmin?).to be true
    expect(User.new(rol: "comercializador").comercializador?).to be true
    expect(User.new(rol: "superadmin").global?).to be true
    expect(User.new(rol: "miembro").global?).to be false
  end

  # El embudo del cambio de organización (tarea 2026-08-31): la ÚNICA
  # dirección puesto → cache.
  describe "#estacionar_en!" do
    let(:megaplex) { tenants(:megaplex) }

    it "sin puesto en el tenant destino levanta y NO toca la cache" do
      user = users(:one) # puesto solo en advance_fitness

      expect { user.estacionar_en!(megaplex) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(user.reload.tenant_id).to eq(tenants(:advance_fitness).id)
      expect(user.rol).to eq("miembro")
    end

    it "con puesto sincroniza tenant_id y rol de la cache copiando DEL puesto" do
      user = users(:one)
      user.puestos.create!(tenant: megaplex, rol: "entrenador")

      user.estacionar_en!(megaplex)

      expect(user.reload.tenant_id).to eq(megaplex.id)
      expect(user.rol).to eq("entrenador") # el rol de ALLÁ, no el que traía
    end

    # El juego es DE LA PERSONA (Nota 29, D1): el perfil sigue a la cuenta.
    # Antes, `users.tenant_id` se reescribía y `perfiles_juego.tenant_id` no:
    # todo `perfil.update!` posterior levantaba RecordInvalid ("Tenant debe
    # coincidir con el de user") — Racha, Otorgador, Recalculador y el job.
    describe "el perfil de juego sigue a la cuenta" do
      let(:user) { users(:one) }

      before { user.puestos.create!(tenant: megaplex, rol: "miembro") }

      it "re-sincroniza el tenant del perfil y perfil.update! deja de levantar RecordInvalid" do
        perfil = PerfilJuego.para(user)

        user.estacionar_en!(megaplex)

        expect { perfil.reload.update!(racha_actual: 3) }.not_to raise_error
        expect(perfil.reload.tenant_id).to eq(megaplex.id)
      end

      it "conserva lo que es de la persona: puntos, racha, mejor racha y apodo" do
        PerfilJuego.para(user).update!(puntos_total: 250, nivel: 2, racha_actual: 4,
                                       racha_mejor: 9, apodo: "Rayo")

        user.estacionar_en!(megaplex)

        perfil = user.reload.perfil_juego
        expect(perfil).to have_attributes(puntos_total: 250, nivel: 2, racha_actual: 4,
                                          racha_mejor: 9, apodo: "Rayo")
      end

      it "sin perfil de juego no hace nada de más (la cuenta aún no ha jugado)" do
        expect { user.estacionar_en!(megaplex) }.not_to change(PerfilJuego, :count)
        expect(user.reload.tenant_id).to eq(megaplex.id)
      end

      it "estacionar donde ya está parada es no-op: no toca el opt-in del ranking" do
        perfil = PerfilJuego.para(user)
        perfil.update!(visible_en_tabla: true)

        user.estacionar_en!(tenants(:advance_fitness))

        expect(perfil.reload.visible_en_tabla).to be(true)
      end

      # PRIVACIDAD fail-closed: el opt-in se dio en el gimnasio viejo. El
      # consentimiento no distingue tenant, así que no viaja — quien llega a
      # un gimnasio nuevo no aparece ni en su tabla ni en su muro sin haber
      # consentido ahí.
      describe "privacidad: el opt-in del gimnasio viejo no viaja" do
        def otorgar!(tipo)
          Consentimiento.create!(user: user, tipo: tipo, accion: "otorgado", version_texto: "v1")
        end

        it "visible_en_tabla vuelve a false y el ranking del gimnasio nuevo no lo lista" do
          PerfilJuego.para(user).update!(visible_en_tabla: true, puntos_total: 500)
          otorgar!("tabla_posiciones")

          user.estacionar_en!(megaplex)

          expect(user.reload.perfil_juego.visible_en_tabla).to be(false)
          visibles = PerfilJuego.where(tenant_id: megaplex.id, visible_en_tabla: true)
          expect(visibles.pluck(:user_id)).not_to include(user.id)
        end

        it "deja el rastro append-only: revoca tabla_posiciones y logros_comunidad vigentes" do
          PerfilJuego.para(user).update!(visible_en_tabla: true)
          otorgar!("tabla_posiciones")
          otorgar!("logros_comunidad")

          user.estacionar_en!(megaplex)

          expect(Consentimiento.vigente?(user, "tabla_posiciones")).to be(false)
          expect(Consentimiento.vigente?(user, "logros_comunidad")).to be(false)
          revocacion = Consentimiento.where(user: user, accion: "revocado")
          expect(revocacion.pluck(:version_texto).uniq).to eq([ Consentimiento::VERSION_CAMBIO_DE_GIMNASIO ])
        end

        it "revoca el muro aunque la cuenta no tenga perfil de juego todavía" do
          otorgar!("logros_comunidad")

          user.estacionar_en!(megaplex)

          expect(Consentimiento.vigente?(user, "logros_comunidad")).to be(false)
        end

        it "no ensucia el rastro si no había nada vigente que revocar" do
          PerfilJuego.para(user)
          otorgar!("logros_comunidad")
          Consentimiento.create!(user: user, tipo: "logros_comunidad", accion: "revocado",
                                 version_texto: "v1")

          expect { user.estacionar_en!(megaplex) }.not_to change(Consentimiento, :count)
        end
      end
    end
  end

  # El espejo cache → puestos (after_save): garantiza que toda cuenta creada
  # o movida por los flujos legados (registro, alta del mostrador, admin
  # inicial de un tenant nuevo, seeds) nazca con el puesto que
  # `verificar_pertenencia_al_tenant` va a exigir.
  describe "sincronización del puesto con la cache" do
    it "al crear un user con tenant nace su puesto espejo con el mismo rol" do
      user = User.create!(email_address: "nueva@x.com", password: "clave1234",
                          rol: "recepcion", tenant: tenants(:megaplex), nombre: "Nueva")

      expect(user.puestos.pluck(:tenant_id, :rol)).to eq([ [ tenants(:megaplex).id, "recepcion" ] ])
    end

    it "al cambiar el rol de la cache se sincroniza el puesto del par estacionado" do
      users(:one).update!(rol: "entrenador")

      expect(puestos(:one).reload.rol).to eq("entrenador")
    end

    it "los roles globales jamás generan puesto" do
      sa = User.create!(email_address: "sa2@x.com", password: "clave1234",
                        rol: "superadmin", nombre: "SA")

      expect(sa.puestos).to be_empty
    end
  end
end
