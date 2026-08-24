require "rails_helper"

RSpec.describe CalculadoraUnaRepMax do
  it "estima el 1RM con la fórmula de Epley" do
    # 100 × (1 + 5/30) = 116.666... → 116.7
    expect(described_class.estimar(peso_kg: 100, repeticiones: 5)).to be_within(0.01).of(116.7)
  end

  it "con 1 repetición el estimado es apenas mayor al peso (así es Epley)" do
    # 80 × (1 + 1/30) = 82.666... → 82.7 — la fórmula no es exactamente
    # identidad en 1 rep, es una propiedad conocida de Epley, no un bug.
    expect(described_class.estimar(peso_kg: 80, repeticiones: 1)).to eq(82.7)
  end

  it "no estima por encima de 12 repeticiones (el error de la fórmula crece demasiado)" do
    expect(described_class.estimar(peso_kg: 60, repeticiones: 13)).to be_nil
  end

  it "no estima sin peso o sin repeticiones" do
    expect(described_class.estimar(peso_kg: nil, repeticiones: 8)).to be_nil
    expect(described_class.estimar(peso_kg: 60, repeticiones: nil)).to be_nil
    expect(described_class.estimar(peso_kg: 60, repeticiones: 0)).to be_nil
  end
end
