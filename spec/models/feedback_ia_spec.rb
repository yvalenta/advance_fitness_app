require "rails_helper"

RSpec.describe FeedbackIa, type: :model do
  let(:registro) { RegistroEntrenamiento.create!(user: users(:one), fecha: Date.current) }
  let(:feedback) { registro.create_feedback_ia!(estado: "pendiente") }

  it "marcar_generando! limpia el error y pone estado generando" do
    feedback.update!(estado: "fallido", error: "algo falló")
    feedback.marcar_generando!
    expect(feedback.reload.estado).to eq("generando")
    expect(feedback.error).to be_nil
  end

  it "completar! guarda el diagnóstico y limpia el error" do
    feedback.marcar_generando!
    feedback.completar!(diagnostico: "progreso", analisis: "vas bien", accion_recomendada: "sube 2kg", modelo: "gemini-test")

    feedback.reload
    expect(feedback.listo?).to be true
    expect(feedback.diagnostico).to eq("progreso")
    expect(feedback.analisis).to eq("vas bien")
    expect(feedback.error).to be_nil
  end

  it "fallar! trunca el mensaje y suma un intento" do
    expect { feedback.fallar!("boom" * 200) }.to change { feedback.reload.intentos }.by(1)
    expect(feedback.fallido?).to be true
    expect(feedback.error.length).to be <= 500
  end

  it "rechaza un diagnóstico fuera del contrato" do
    feedback.diagnostico = "inventado"
    expect(feedback).not_to be_valid
  end

  describe ".estancados" do
    it "incluye solo los que llevan generando más de 10 minutos" do
      viejo = feedback
      viejo.update!(estado: "generando", updated_at: 15.minutes.ago)

      otro_registro = RegistroEntrenamiento.create!(user: users(:two), fecha: Date.current)
      reciente = otro_registro.create_feedback_ia!(estado: "generando")

      expect(FeedbackIa.estancados).to include(viejo)
      expect(FeedbackIa.estancados).not_to include(reciente)
    end
  end
end
