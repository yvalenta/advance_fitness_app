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

  it "un miembro premium registra una serie y la ve en la lista" do
    sign_in_as users(:one)
    premium!(users(:one))

    expect {
      post detalles_entrenamiento_path, params: {
        fecha: Date.current.iso8601, ejercicio_id: ejercicio.id, nombre: ejercicio.nombre,
        repeticiones: 10, peso_kg: 40
      }
    }.to change(DetalleEntrenamiento, :count).by(1)
    expect(response).to have_http_status(:success)
    expect(response.body).to include("40")

    detalle = DetalleEntrenamiento.last
    expect(detalle.serie).to eq(1)
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

  it "el dueño quita su propia serie" do
    sign_in_as users(:one)
    premium!(users(:one))
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    detalle = registro.detalles.create!(ejercicio: ejercicio, serie: 1, repeticiones: 10, peso_kg: 40)

    expect {
      delete detalle_entrenamiento_path(detalle)
    }.to change(DetalleEntrenamiento, :count).by(-1)
    expect(response).to have_http_status(:success)
  end

  it "otro usuario no puede quitar una serie ajena" do
    sign_in_as users(:two)
    premium!(users(:one))
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    detalle = registro.detalles.create!(ejercicio: ejercicio, serie: 1, repeticiones: 10, peso_kg: 40)

    expect { delete detalle_entrenamiento_path(detalle) }.not_to change(DetalleEntrenamiento, :count)
    expect(response).to redirect_to(root_path)
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

  it "muestra el dialog de registro (index) solo con el ejercicio resuelto" do
    sign_in_as users(:one)
    premium!(users(:one))

    get detalles_entrenamiento_path, params: { fecha: Date.current.iso8601, ejercicio_id: ejercicio.id, nombre: ejercicio.nombre }
    expect(response).to have_http_status(:success)
    expect(response.body).to include(ejercicio.nombre)
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
