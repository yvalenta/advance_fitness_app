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
end
