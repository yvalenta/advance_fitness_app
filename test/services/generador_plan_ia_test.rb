require "test_helper"

class GeneradorPlanIaTest < ActiveSupport::TestCase
  test "el prompt incluye los datos del perfil y el objetivo" do
    prompt = GeneradorPlanIa.construir_prompt(
      edad: 30, sexo: "F", talla_cm: 165.0, peso_kg: 60.0, somatotipo: "ectomorfo",
      nivel_actividad: 1.6, meta: "Ganar masa", objetivo_kcal: 2500, tdee_kcal: 2000
    )

    assert_match "30 años", prompt
    assert_match "mujer", prompt
    assert_match "165.0 cm", prompt
    assert_match "ectomorfo", prompt
    assert_match "2500 kcal", prompt
  end

  test "parsear acepta JSON limpio y envuelto en fences" do
    json = '{"rutina": {"dias": []}, "plan_nutricional": {"comidas": []}}'

    [ json, "```json\n#{json}\n```", "```\n#{json}\n```" ].each do |texto|
      resultado = GeneradorPlanIa.parsear(texto)
      assert_equal({ "dias" => [] }, resultado[:rutina])
      assert_equal({ "comidas" => [] }, resultado[:plan_nutricional])
    end
  end

  test "parsear rechaza respuestas sin el contrato completo" do
    assert_raises(ArgumentError) { GeneradorPlanIa.parsear('{"rutina": {"dias": []}}') }
    assert_raises(JSON::ParserError) { GeneradorPlanIa.parsear("no soy json") }
  end

  test "el proveedor se elige por IA_PROVEEDOR con gemini por defecto" do
    con_proveedor(nil) { assert_equal Ia::ProveedorGemini, GeneradorPlanIa.proveedor }
    con_proveedor("gemini") { assert_equal Ia::ProveedorGemini, GeneradorPlanIa.proveedor }
    con_proveedor("Claude") { assert_equal Ia::ProveedorClaude, GeneradorPlanIa.proveedor }
  end

  test "un proveedor desconocido levanta error con las opciones válidas" do
    error = con_proveedor("gpt") { assert_raises(ArgumentError) { GeneradorPlanIa.proveedor } }
    assert_match "gemini | claude", error.message
  end

  test "el cuerpo de Gemini fuerza salida JSON y lleva system y prompt" do
    cuerpo = Ia::ProveedorGemini.cuerpo(system: "eres coach", prompt: "genera el plan")

    assert_equal "application/json", cuerpo.dig(:generationConfig, :responseMimeType)
    assert_equal "eres coach", cuerpo.dig(:system_instruction, :parts, 0, :text)
    assert_equal "genera el plan", cuerpo.dig(:contents, 0, :parts, 0, :text)
  end

  test "el cuerpo de Claude lleva modelo, system y prompt" do
    cuerpo = Ia::ProveedorClaude.cuerpo(system: "eres coach", prompt: "genera el plan")

    assert_equal Ia::ProveedorClaude::MODELO, cuerpo[:model]
    assert_equal "eres coach", cuerpo[:system]
    assert_equal "genera el plan", cuerpo.dig(:messages, 0, :content)
  end

  private

  # Fija IA_PROVEEDOR durante el bloque y lo restaura siempre.
  def con_proveedor(nombre)
    anterior = ENV["IA_PROVEEDOR"]
    nombre.nil? ? ENV.delete("IA_PROVEEDOR") : ENV["IA_PROVEEDOR"] = nombre
    yield
  ensure
    anterior.nil? ? ENV.delete("IA_PROVEEDOR") : ENV["IA_PROVEEDOR"] = anterior
  end
end
