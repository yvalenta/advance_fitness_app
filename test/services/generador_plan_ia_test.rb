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

  test "el prompt incluye la antropometría cuando hay medición" do
    medicion = Medicion.new(peso_kg: 80, grasa_pct: 18, cintura_cm: 85, pliegue_abdominal_mm: 15)
    prompt = GeneradorPlanIa.construir_prompt(
      edad: 30, sexo: "M", talla_cm: 178.0, peso_kg: 80.0, somatotipo: "mesomorfo",
      nivel_actividad: 1.6, meta: "Ganar masa", objetivo_kcal: 2800, tdee_kcal: 2400, medicion: medicion
    )

    assert_match "Medidas antropométricas", prompt
    assert_match "Grasa corporal: 18", prompt
    assert_match "Cintura 85", prompt
    assert_match "Abdominal 15", prompt
  end

  test "sin medición el prompt no agrega el bloque de antropometría" do
    prompt = GeneradorPlanIa.construir_prompt(
      edad: 30, sexo: "M", talla_cm: 178.0, peso_kg: 80.0, somatotipo: "mesomorfo",
      nivel_actividad: 1.6, meta: "x", objetivo_kcal: 2000, tdee_kcal: 1800
    )

    assert_no_match(/Medidas antropométricas/, prompt)
  end

  # Fase 6.5: catálogo cerrado de ejercicios en el prompt
  test "el prompt incluye el catálogo permitido y el system exige ids exactos" do
    prompt = GeneradorPlanIa.construir_prompt(
      edad: 30, sexo: "M", talla_cm: 178.0, peso_kg: 80.0, somatotipo: "mesomorfo",
      nivel_actividad: 1.6, meta: "x", objetivo_kcal: 2000, tdee_kcal: 1800,
      catalogo: "PECHO:\n12 | Press de banca (barbell)"
    )

    assert_match "CATÁLOGO PERMITIDO", prompt
    assert_match "12 | Press de banca", prompt
    assert_match "EXCLUSIVAMENTE", GeneradorPlanIa::SYSTEM_PROMPT
    assert_match "peso_sugerido_kg", GeneradorPlanIa::SYSTEM_PROMPT
    assert_match "nota_tecnica", GeneradorPlanIa::SYSTEM_PROMPT
  end

  # Fase 6.6: bloque de adherencia real al regenerar
  test "el prompt resume la adherencia con lo flojo y las novedades" do
    prompt = GeneradorPlanIa.construir_prompt(
      edad: 30, sexo: "M", talla_cm: 178.0, peso_kg: 80.0, somatotipo: "mesomorfo",
      nivel_actividad: 1.6, meta: "x", objetivo_kcal: 2000, tdee_kcal: 1800,
      adherencia: { semanas: 4, pct_global: 55,
                    por_ejercicio: [ { nombre: "Sentadilla", hechos: 1, total: 4 },
                                     { nombre: "Press banca", hechos: 4, total: 4 } ],
                    novedades: [ "me dolió el hombro" ] }
    )

    assert_match "Adherencia real del miembro (últimas 4 semanas): 55%", prompt
    assert_match "Baja adherencia en: Sentadilla (1/4)", prompt
    assert_no_match(/Baja adherencia en:.*Press banca/, prompt)
    assert_match "me dolió el hombro", prompt
  end

  test "sin catálogo ni adherencia el prompt no agrega esos bloques" do
    prompt = GeneradorPlanIa.construir_prompt(
      edad: 30, sexo: "M", talla_cm: 178.0, peso_kg: 80.0, somatotipo: "mesomorfo",
      nivel_actividad: 1.6, meta: "x", objetivo_kcal: 2000, tdee_kcal: 1800
    )

    assert_no_match(/CATÁLOGO PERMITIDO/, prompt)
    assert_no_match(/Adherencia real/, prompt)
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
