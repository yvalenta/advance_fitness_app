require "rails_helper"

RSpec.describe MensajeIa, type: :model do
  it "traduce cada categoría de error a un mensaje corto" do
    expect(MensajeIa.amistoso("Your credit balance is too low")).to match(/cr[eé]ditos/i)
    expect(MensajeIa.amistoso("Gemini API 503: high demand")).to match(/ocupado/i)
    expect(MensajeIa.amistoso("429 rate limit exceeded")).to match(/l[ií]mite/i)
    expect(MensajeIa.amistoso("Net::ReadTimeout timed out")).to match(/tard[oó]/i)
    expect(MensajeIa.amistoso("JSON::ParserError unexpected token")).to match(/inv[aá]lida/i)
    expect(MensajeIa.amistoso("algo raro pasó")).to eq(MensajeIa::GENERICO)
  end

  it "ocupado? detecta solo los fallos por modelo saturado" do
    expect(MensajeIa.ocupado?("Gemini API 503: UNAVAILABLE")).to be_truthy
    expect(MensajeIa.ocupado?("model is overloaded")).to be_truthy
    expect(MensajeIa.ocupado?("credit balance too low")).to be_falsey
  end
end
