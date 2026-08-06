require "rails_helper"

# Regresión (Fase de Calidad): la Fase 8 dejó el controller y el link del
# navbar sin la vista pública — /novedades reventaba con MissingExactTemplate.
# Fase 18f: además, el listado pasa por policy_scope — solo el tenant propio.
RSpec.describe "Novedades públicas", type: :request do
  it "un miembro ve solo las novedades publicadas" do
    publicada = Novedad.create!(titulo: "Clase de yoga", contenido: "Sábado 9am",
                                publicado: true, tenant: tenants(:advance_fitness))
    Novedad.create!(titulo: "Borrador interno", contenido: "x", tenant: tenants(:advance_fitness))
    sign_in_as users(:one)

    get novedades_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include(publicada.titulo)
    expect(response.body).not_to include("Borrador interno")
  end

  it "no muestra novedades de otro tenant aunque estén publicadas" do
    Novedad.create!(titulo: "Promo ajena", contenido: "x",
                    publicado: true, tenant: tenants(:megaplex))
    sign_in_as users(:one)

    get novedades_path

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include("Promo ajena")
  end

  # Muro de la comunidad (Fase 18e): celebraciones derivadas de PRs/logros de
  # miembros con consentimiento `logros_comunidad` — cero digitación.
  describe "muro de la comunidad" do
    def ejercicio(nombre, dataset)
      Ejercicio.create!(dataset_id: dataset, nombre: nombre, nombre_en: nombre,
                        nombre_normalizado: nombre.downcase, categoria: "fuerza", musculo: "pecho")
    end

    def consentir!(user)
      user.consentimientos.create!(tipo: "logros_comunidad", accion: "otorgado",
                                   version_texto: "muro-v1")
    end

    it "celebra marcas de miembros con opt-in y calla a los demás" do
      consentir!(users(:one))
      RecordPersonal.create!(user: users(:one), ejercicio: ejercicio("Press banca", "muro-0001"),
                             tipo: "peso_max", valor: 80, fecha: Date.current)
      RecordPersonal.create!(user: users(:two), ejercicio: ejercicio("Sentadilla", "muro-0002"),
                             tipo: "peso_max", valor: 100, fecha: Date.current)
      sign_in_as users(:one)

      get novedades_path

      expect(response.body).to include("Press banca")
      expect(response.body).to include("80 kg")
      expect(response.body).not_to include("Sentadilla")
    end

    it "un logro obtenido se celebra con su nombre y puntos" do
      consentir!(users(:one))
      logro = Logro.create!(codigo: "muro-prueba", nombre: "Racha de hierro",
                            puntos: 50, categoria: "constancia")
      LogroObtenido.create!(user: users(:one), logro: logro, obtenido_en: Time.current)
      sign_in_as users(:one)

      get novedades_path

      expect(response.body).to include("Racha de hierro")
      expect(response.body).to include("+50 pts")
    end

    it "las celebraciones jamás cruzan tenants" do
      miembro_mp = User.create!(email_address: "miembro-mp@x.com", password: "clave1234",
                                rol: "miembro", tenant: tenants(:megaplex), nombre: "Ajeno MP")
      consentir!(miembro_mp)
      RecordPersonal.create!(user: miembro_mp, ejercicio: ejercicio("Remo ajeno", "muro-0003"),
                             tipo: "peso_max", valor: 70, fecha: Date.current)
      sign_in_as users(:one)

      get novedades_path

      expect(response.body).not_to include("Remo ajeno")
      expect(response.body).not_to include("Ajeno")
    end

    it "participar y retirarse dejan rastro append-only" do
      sign_in_as users(:one)

      expect { post novedades_participacion_path }.to change(Consentimiento, :count).by(1)
      expect(Consentimiento.vigente?(users(:one), "logros_comunidad")).to be true

      # Repetir el POST no re-otorga (sin fila nueva)
      expect { post novedades_participacion_path }.not_to change(Consentimiento, :count)

      expect { delete novedades_participacion_path }.to change(Consentimiento, :count).by(1)
      expect(Consentimiento.vigente?(users(:one), "logros_comunidad")).to be false
    end
  end
end
