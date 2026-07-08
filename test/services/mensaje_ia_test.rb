require "test_helper"

class MensajeIaTest < ActiveSupport::TestCase
  test "traduce cada categoría de error a un mensaje corto" do
    assert_match(/cr[eé]ditos/i, MensajeIa.amistoso("Your credit balance is too low"))
    assert_match(/ocupado/i,     MensajeIa.amistoso("Gemini API 503: high demand"))
    assert_match(/l[ií]mite/i,   MensajeIa.amistoso("429 rate limit exceeded"))
    assert_match(/tard[oó]/i,    MensajeIa.amistoso("Net::ReadTimeout timed out"))
    assert_match(/inv[aá]lida/i, MensajeIa.amistoso("JSON::ParserError unexpected token"))
    assert_equal MensajeIa::GENERICO, MensajeIa.amistoso("algo raro pasó")
  end

  test "ocupado? detecta solo los fallos por modelo saturado" do
    assert MensajeIa.ocupado?("Gemini API 503: UNAVAILABLE")
    assert MensajeIa.ocupado?("model is overloaded")
    assert_not MensajeIa.ocupado?("credit balance too low")
  end
end
