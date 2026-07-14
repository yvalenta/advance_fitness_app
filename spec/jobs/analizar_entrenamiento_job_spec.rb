require "rails_helper"

RSpec.describe AnalizarEntrenamientoJob, type: :job do
  def resultado
    { diagnostico: "progreso", analisis: "vas bien", accion_recomendada: "sube 2kg", modelo: "gemini-test" }.freeze
  end

  def con_ia_stub(respuesta)
    original = GeneradorFeedbackIa.method(:generar)
    GeneradorFeedbackIa.define_singleton_method(:generar) do |*args|
      respuesta.respond_to?(:call) ? respuesta.call(*args) : respuesta
    end
    yield
  ensure
    GeneradorFeedbackIa.define_singleton_method(:generar, original)
  end

  let(:ejercicio) do
    Ejercicio.create!(dataset_id: "test-job-0001", nombre: "Sentadilla", nombre_en: "Squat",
                      nombre_normalizado: "sentadilla", categoria: "fuerza", musculo: "pierna")
  end
  let(:registro) { RegistroEntrenamiento.create!(user: users(:one), fecha: Date.current) }

  def premium!
    Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
  end

  it "completa el feedback de un miembro premium" do
    premium!
    registro.detalles.create!(ejercicio: ejercicio, serie: 1, repeticiones: 10, peso_kg: 60)

    con_ia_stub(resultado) { AnalizarEntrenamientoJob.perform_now(registro.id) }

    feedback = registro.reload.feedback_ia
    expect(feedback.listo?).to be true
    expect(feedback.diagnostico).to eq("progreso")
    expect(feedback.modelo).to eq("gemini-test")
  end

  it "sin suscripción premium marca fallido y no llama a la IA" do
    centinela = ->(*) { raise "la IA no debe llamarse sin suscripción" }

    con_ia_stub(centinela) { AnalizarEntrenamientoJob.perform_now(registro.id) }

    expect(registro.reload.feedback_ia.fallido?).to be true
    expect(registro.feedback_ia.error).to match(/suscripción/i)
  end

  it "un fallo de la IA deja el feedback en fallido con su mensaje" do
    premium!

    con_ia_stub(->(*) { raise "Gemini API 503: overloaded" }) do
      AnalizarEntrenamientoJob.perform_now(registro.id)
    end

    feedback = registro.reload.feedback_ia
    expect(feedback.fallido?).to be true
    expect(feedback.intentos).to eq(1)
    expect(feedback.error).to match("503")
  end

  it "envía las series más recientes del usuario, sin importar el ejercicio o el día" do
    premium!
    otro_dia = RegistroEntrenamiento.create!(user: users(:one), fecha: Date.yesterday)
    otro_dia.detalles.create!(ejercicio: ejercicio, serie: 1, repeticiones: 8, peso_kg: 50)
    perfil_visto = nil

    con_ia_stub(->(perfil) { perfil_visto = perfil; resultado }) { AnalizarEntrenamientoJob.perform_now(registro.id) }

    expect(perfil_visto[:series].map { |s| s[:ejercicio] }).to include("Sentadilla")
  end
end
