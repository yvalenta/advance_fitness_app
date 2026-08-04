require "rails_helper"

RSpec.describe Ciclo::Ajuste do
  let(:shape) { %w[series_delta peso_factor reps_delta kcal_delta mensaje] }

  it "toda fase expone el shape del ajuste de mesociclo + kcal_delta y mensaje" do
    Ciclo::Fase::FASES.each do |fase|
      expect(described_class.para(fase).keys).to match_array(shape),
        "la fase #{fase} no respeta el shape"
    end
  end

  # REGLA DURA property-style: la fase solo BAJA carga o la deja igual —
  # jamás la sube. Si alguien agrega una fase o "premia" la folicular con
  # más peso, este spec falla.
  it "ninguna fase sube la carga (peso_factor <= 1.0, deltas <= 0)" do
    Ciclo::Fase::FASES.each do |fase|
      ajuste = described_class.para(fase)
      expect(ajuste["peso_factor"]).to be <= 1.0, "peso_factor de #{fase} sube la carga"
      expect(ajuste["series_delta"]).to be <= 0, "series_delta de #{fase} sube la carga"
      expect(ajuste["reps_delta"]).to be <= 0, "reps_delta de #{fase} sube la carga"
    end
  end

  it ":desconocida es la identidad exacta (NULO): el módulo se vuelve invisible" do
    expect(described_class.para(:desconocida)).to eq(described_class::NULO)
    expect(described_class::NULO).to eq(
      "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0,
      "kcal_delta" => 0, "mensaje" => nil
    )
  end

  it "una fase no reconocida (o nil) degrada a NULO, nunca revienta" do
    expect(described_class.para(:inventada)).to eq(described_class::NULO)
    expect(described_class.para(nil)).to eq(described_class::NULO)
  end

  it "acepta la fase como string (viene de shapes serializados)" do
    expect(described_class.para("menstrual")).to eq(described_class.para(:menstrual))
  end

  it "menstrual: baja al 0.85 y quita una serie" do
    ajuste = described_class.para(:menstrual)
    expect(ajuste["peso_factor"]).to eq(0.85)
    expect(ajuste["series_delta"]).to eq(-1)
  end

  it "lútea: baja al 0.9 y sugiere más kcal (el hambre sube, la carga no)" do
    ajuste = described_class.para(:lutea)
    expect(ajuste["peso_factor"]).to eq(0.9)
    expect(ajuste["kcal_delta"]).to be_positive
  end

  it "folicular y ovulación: identidad de carga con mensaje de energía alta" do
    %i[folicular ovulacion].each do |fase|
      ajuste = described_class.para(fase)
      expect(ajuste.slice("series_delta", "peso_factor", "reps_delta", "kcal_delta"))
        .to eq(described_class::NULO.slice("series_delta", "peso_factor", "reps_delta", "kcal_delta"))
      expect(ajuste["mensaje"]).to match(/energía/i)
    end
  end
end
