require "rails_helper"

RSpec.describe GeneradorFeedbackIa do
  describe ".parsear" do
    it "acepta un JSON válido con las 3 claves" do
      texto = '{"diagnostico":"progreso","analisis":"vas bien","accion_recomendada":"sube carga"}'
      resultado = described_class.parsear(texto)

      expect(resultado).to eq(diagnostico: "progreso", analisis: "vas bien", accion_recomendada: "sube carga")
    end

    it "limpia fences de markdown" do
      texto = "```json\n{\"diagnostico\":\"estancado\",\"analisis\":\"a\",\"accion_recomendada\":\"b\"}\n```"
      expect(described_class.parsear(texto)[:diagnostico]).to eq("estancado")
    end

    it "cae a 'alerta' si el diagnóstico no está en el contrato, sin perder el análisis" do
      texto = '{"diagnostico":"super_mal","analisis":"algo raro","accion_recomendada":"revisa"}'
      resultado = described_class.parsear(texto)

      expect(resultado[:diagnostico]).to eq("alerta")
      expect(resultado[:analisis]).to include("algo raro")
    end

    it "revienta si falta alguna de las 3 claves" do
      expect { described_class.parsear('{"diagnostico":"progreso","analisis":"a"}') }.to raise_error(ArgumentError)
    end
  end

  describe ".construir_prompt" do
    it "arma una línea legible por serie" do
      perfil = { series: [ { ejercicio: "Sentadilla", fecha: "2026-07-01", serie: 1, repeticiones: 10, peso_kg: 60, rpe: 8 } ] }
      prompt = described_class.construir_prompt(perfil)

      expect(prompt).to include("Sentadilla")
      expect(prompt).to include("60 kg")
      expect(prompt).to include("RPE 8")
    end

    it "avisa cuando no hay series" do
      expect(described_class.construir_prompt(series: [])).to match(/no tiene series registradas/i)
    end
  end
end
