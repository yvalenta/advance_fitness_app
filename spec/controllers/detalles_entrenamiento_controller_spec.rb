require "rails_helper"

RSpec.describe "DetallesEntrenamiento", type: :request do
  let(:ejercicio) do
    Ejercicio.create!(dataset_id: "test-ctrl-0001", nombre: "Peso muerto", nombre_en: "Deadlift",
                      nombre_normalizado: "peso muerto", categoria: "fuerza", musculo: "espalda")
  end

  def premium!(user)
    Suscripcion.create!(user: user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
  end

  it "un miembro free no puede registrar series (redirect, sin crear nada)" do
    sign_in_as users(:one)

    expect {
      post detalles_entrenamiento_path, params: {
        fecha: Date.current.iso8601, ejercicio_id: ejercicio.id, nombre: ejercicio.nombre,
        repeticiones: 10, peso_kg: 40
      }
    }.not_to change(DetalleEntrenamiento, :count)
    expect(response).to redirect_to(root_path)
  end

  it "un miembro premium registra una serie" do
    sign_in_as users(:one)
    premium!(users(:one))

    expect {
      post detalles_entrenamiento_path, params: {
        fecha: Date.current.iso8601, ejercicio_id: ejercicio.id, nombre: ejercicio.nombre,
        repeticiones: 10, peso_kg: 40
      }
    }.to change(DetalleEntrenamiento, :count).by(1)
    expect(response).to have_http_status(:success)

    detalle = DetalleEntrenamiento.last
    expect(detalle.serie).to eq(1)
    expect(detalle.peso_kg).to eq(40)
    expect(detalle.registro_entrenamiento.user).to eq(users(:one))
  end

  it "cada serie nueva incrementa el número de serie para el mismo ejercicio" do
    sign_in_as users(:one)
    premium!(users(:one))
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    registro.detalles.create!(ejercicio: ejercicio, serie: 1, repeticiones: 10, peso_kg: 40)

    post detalles_entrenamiento_path, params: {
      fecha: Date.current.iso8601, ejercicio_id: ejercicio.id, nombre: ejercicio.nombre,
      repeticiones: 8, peso_kg: 42
    }

    expect(registro.detalles.order(:serie).pluck(:serie)).to eq([ 1, 2 ])
  end

  it "resuelve el ejercicio por nombre cuando falta ejercicio_id (planes viejos)" do
    sign_in_as users(:one)
    premium!(users(:one))
    ejercicio # fuerza la creación antes de buscar por nombre

    expect {
      post detalles_entrenamiento_path, params: {
        fecha: Date.current.iso8601, ejercicio_id: "", nombre: "Peso Muerto",
        repeticiones: 5, peso_kg: 100
      }
    }.to change(DetalleEntrenamiento, :count).by(1)
    expect(DetalleEntrenamiento.last.ejercicio).to eq(ejercicio)
  end

  it "sin match de ejercicio no crea nada" do
    sign_in_as users(:one)
    premium!(users(:one))

    expect {
      post detalles_entrenamiento_path, params: {
        fecha: Date.current.iso8601, ejercicio_id: "", nombre: "Ejercicio inventado",
        repeticiones: 5, peso_kg: 10
      }
    }.not_to change(DetalleEntrenamiento, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  describe "récords personales en el create (Fase 14.13)" do
    before do
      sign_in_as users(:one)
      premium!(users(:one))
    end

    # Vara previa: una serie de ayer ya evaluada (deja los baselines listos).
    def vara_de_ayer!(reps:, peso:)
      registro = users(:one).registros_entrenamiento.create!(fecha: Date.yesterday)
      detalle = registro.detalles.create!(ejercicio: ejercicio, serie: 1, repeticiones: reps, peso_kg: peso)
      Juego::DetectorPr.evaluar!(detalle)
    end

    # Fase 18n: la celebración viaja como append a #celebraciones_sesion (el
    # contenedor del modo sesión); sin récord la respuesta es un ok vacío.
    it "al batir la marca responde la celebración para la sesión" do
      vara_de_ayer!(reps: 10, peso: 40)

      post detalles_entrenamiento_path, params: {
        fecha: Date.current.iso8601, ejercicio_id: ejercicio.id, nombre: ejercicio.nombre,
        repeticiones: 10, peso_kg: 50
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(%(action="append" target="celebraciones_sesion"))
      expect(response.body).to include("Nuevo récord personal")
      expect(response.body).to include("50 kg")
    end

    it "el primer registro (baseline) no celebra: ok vacío" do
      post detalles_entrenamiento_path, params: {
        fecha: Date.current.iso8601, ejercicio_id: ejercicio.id, nombre: ejercicio.nombre,
        repeticiones: 10, peso_kg: 40
      }

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Nuevo récord personal")
      expect(users(:one).records_personales.where(baseline: true).count).to eq 2
    end

    it "el 'cumplido tal cual' también dispara la detección (peso real levantado)" do
      vara_de_ayer!(reps: 8, peso: 40)

      post detalles_entrenamiento_path, params: {
        fecha: Date.current.iso8601, ejercicio_id: ejercicio.id, nombre: ejercicio.nombre,
        cumplido: "1", series_plan: 3, repeticiones_plan: "8", peso_kg: 45
      }

      expect(response.body).to include("Nuevo récord personal")
      expect(users(:one).records_personales.vigentes.where(baseline: false).pluck(:tipo))
        .to contain_exactly("peso_max", "volumen_max")
    end

    # Fase 18k (bug reportado con captura: 18 series de un plan de 3): el
    # reenvío de "cumplido tal cual" no duplica.
    it "reenviar 'cumplido tal cual' no duplica las series" do
      params_cumplido = { fecha: Date.current.iso8601, ejercicio_id: ejercicio.id, nombre: ejercicio.nombre,
                          cumplido: "1", series_plan: 3, repeticiones_plan: "8-10", peso_kg: 15 }

      expect {
        post detalles_entrenamiento_path, params: params_cumplido
      }.to change(DetalleEntrenamiento, :count).by(3)

      expect {
        post detalles_entrenamiento_path, params: params_cumplido
      }.not_to change(DetalleEntrenamiento, :count)
    end

    # Fase 18l: el modo sesión envía la serie explícita — reintentos y
    # re-visitas del día no duplican.
    it "la serie explícita del modo sesión es idempotente" do
      params_serie = { fecha: Date.current.iso8601, ejercicio_id: ejercicio.id, nombre: ejercicio.nombre,
                       serie: 1, repeticiones: 8, peso_kg: 42.5 }

      expect {
        post detalles_entrenamiento_path, params: params_serie
        post detalles_entrenamiento_path, params: params_serie
      }.to change(DetalleEntrenamiento, :count).by(1)

      detalle = DetalleEntrenamiento.last
      expect(detalle.serie).to eq(1)
      expect(detalle.peso_kg).to eq(42.5)

      post detalles_entrenamiento_path, params: params_serie.merge(serie: 2)
      expect(users(:one).registros_entrenamiento.find_by(fecha: Date.current)
        .detalles.order(:serie).pluck(:serie)).to eq([ 1, 2 ])
    end
  end

  describe "POST /detalles_entrenamiento/analizar" do
    def registrar_series_de_semanas(user, semanas:)
      semanas.times do |i|
        fecha = Date.current.beginning_of_week - i.weeks
        registro = user.registros_entrenamiento.create!(fecha: fecha)
        registro.detalles.create!(ejercicio: ejercicio, serie: 1, repeticiones: 10, peso_kg: 40)
      end
      user.registros_entrenamiento.order(:fecha).last
    end

    it "un miembro no puede disparar el análisis (Fase 12: solo staff)" do
      sign_in_as users(:one)
      premium!(users(:one))
      registro = registrar_series_de_semanas(users(:one), semanas: 3)

      expect {
        post analizar_entrenamiento_path, params: { registro_entrenamiento_id: registro.id }
      }.not_to change(FeedbackIa, :count)
      expect(response).to redirect_to(root_path)
    end

    it "el staff dispara el análisis cuando hay datos suficientes" do
      premium!(users(:one))
      registro = registrar_series_de_semanas(users(:one), semanas: 3)
      sign_in_as users(:entrenador)

      expect {
        post analizar_entrenamiento_path, params: { registro_entrenamiento_id: registro.id }
      }.to have_enqueued_job(AnalizarEntrenamientoJob)
      expect(response).to redirect_to(admin_user_path(users(:one)))
      expect(registro.reload.feedback_ia.generando?).to be true
    end

    it "el staff no puede analizar si faltan datos mínimos" do
      premium!(users(:one))
      registro = registrar_series_de_semanas(users(:one), semanas: 1)
      sign_in_as users(:entrenador)

      expect {
        post analizar_entrenamiento_path, params: { registro_entrenamiento_id: registro.id }
      }.not_to change(FeedbackIa, :count)
      expect(response).to redirect_to(admin_user_path(users(:one)))
    end
  end
end
