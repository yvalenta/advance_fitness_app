require "rails_helper"

RSpec.describe GeneradorPlanIa, type: :model do
  it "el prompt incluye los datos del perfil y el objetivo" do
    prompt = GeneradorPlanIa.construir_prompt(
      edad: 30, sexo: "F", talla_cm: 165.0, peso_kg: 60.0, somatotipo: "ectomorfo",
      nivel_actividad: 1.6, meta: "Ganar masa", objetivo_kcal: 2500, tdee_kcal: 2000
    )

    expect(prompt).to include("30 años")
    expect(prompt).to include("mujer")
    expect(prompt).to include("165.0 cm")
    expect(prompt).to include("ectomorfo")
    expect(prompt).to include("2500 kcal")
  end

  it "el prompt incluye la antropometría cuando hay medición" do
    medicion = Medicion.new(peso_kg: 80, grasa_pct: 18, cintura_cm: 85, pliegue_abdominal_mm: 15)
    prompt = GeneradorPlanIa.construir_prompt(
      edad: 30, sexo: "M", talla_cm: 178.0, peso_kg: 80.0, somatotipo: "mesomorfo",
      nivel_actividad: 1.6, meta: "Ganar masa", objetivo_kcal: 2800, tdee_kcal: 2400, medicion: medicion
    )

    expect(prompt).to include("Medidas antropométricas")
    expect(prompt).to include("Grasa corporal: 18")
    expect(prompt).to include("Cintura 85")
    expect(prompt).to include("Abdominal 15")
  end

  it "sin medición el prompt no agrega el bloque de antropometría" do
    prompt = GeneradorPlanIa.construir_prompt(
      edad: 30, sexo: "M", talla_cm: 178.0, peso_kg: 80.0, somatotipo: "mesomorfo",
      nivel_actividad: 1.6, meta: "x", objetivo_kcal: 2000, tdee_kcal: 1800
    )

    expect(prompt).not_to match(/Medidas antropométricas/)
  end

  # Fase 6.5: catálogo cerrado de ejercicios en el prompt
  it "el prompt incluye el catálogo permitido y el system exige ids exactos" do
    prompt = GeneradorPlanIa.construir_prompt(
      edad: 30, sexo: "M", talla_cm: 178.0, peso_kg: 80.0, somatotipo: "mesomorfo",
      nivel_actividad: 1.6, meta: "x", objetivo_kcal: 2000, tdee_kcal: 1800,
      catalogo: "PECHO:\n12 | Press de banca (barbell)"
    )

    expect(prompt).to include("CATÁLOGO PERMITIDO")
    expect(prompt).to include("12 | Press de banca")
    expect(GeneradorPlanIa::SYSTEM_PROMPT).to include("EXCLUSIVAMENTE")
    expect(GeneradorPlanIa::SYSTEM_PROMPT).to include("peso_sugerido_kg")
    expect(GeneradorPlanIa::SYSTEM_PROMPT).to include("nota_tecnica")
  end

  # Fase 6.6: bloque de adherencia real al regenerar
  it "el prompt resume la adherencia con lo flojo y las novedades" do
    prompt = GeneradorPlanIa.construir_prompt(
      edad: 30, sexo: "M", talla_cm: 178.0, peso_kg: 80.0, somatotipo: "mesomorfo",
      nivel_actividad: 1.6, meta: "x", objetivo_kcal: 2000, tdee_kcal: 1800,
      adherencia: { semanas: 4, pct_global: 55,
                    por_ejercicio: [ { nombre: "Sentadilla", hechos: 1, total: 4 },
                                     { nombre: "Press banca", hechos: 4, total: 4 } ],
                    novedades: [ "me dolió el hombro" ] }
    )

    expect(prompt).to include("Adherencia real del miembro (últimas 4 semanas): 55%")
    expect(prompt).to include("Baja adherencia en: Sentadilla (1/4)")
    expect(prompt).not_to match(/Baja adherencia en:.*Press banca/)
    expect(prompt).to include("me dolió el hombro")
  end

  it "sin catálogo ni adherencia el prompt no agrega esos bloques" do
    prompt = GeneradorPlanIa.construir_prompt(
      edad: 30, sexo: "M", talla_cm: 178.0, peso_kg: 80.0, somatotipo: "mesomorfo",
      nivel_actividad: 1.6, meta: "x", objetivo_kcal: 2000, tdee_kcal: 1800
    )

    expect(prompt).not_to match(/CATÁLOGO PERMITIDO/)
    expect(prompt).not_to match(/Adherencia real/)
  end

  it "parsear acepta JSON limpio y envuelto en fences" do
    json = '{"rutina": {"dias": []}, "plan_nutricional": {"comidas": []}}'

    [ json, "```json\n#{json}\n```", "```\n#{json}\n```" ].each do |texto|
      resultado = GeneradorPlanIa.parsear(texto)
      expect(resultado[:rutina]).to eq({ "dias" => [] })
      expect(resultado[:plan_nutricional]).to eq({ "comidas" => [] })
    end
  end

  it "parsear rechaza respuestas sin el contrato completo" do
    expect { GeneradorPlanIa.parsear('{"rutina": {"dias": []}}') }.to raise_error(ArgumentError)
    expect { GeneradorPlanIa.parsear("no soy json") }.to raise_error(JSON::ParserError)
  end

  it "el proveedor se elige por IA_PROVEEDOR con gemini por defecto" do
    con_proveedor(nil) { expect(GeneradorPlanIa.proveedor).to eq(Ia::ProveedorGemini) }
    con_proveedor("gemini") { expect(GeneradorPlanIa.proveedor).to eq(Ia::ProveedorGemini) }
    con_proveedor("Claude") { expect(GeneradorPlanIa.proveedor).to eq(Ia::ProveedorClaude) }
  end

  it "un proveedor desconocido levanta error con las opciones válidas" do
    error = nil
    con_proveedor("gpt") do
      begin
        GeneradorPlanIa.proveedor
      rescue ArgumentError => e
        error = e
      end
    end
    expect(error).to be_a(ArgumentError)
    expect(error.message).to include("gemini | claude")
  end

  it "el cuerpo de Gemini fuerza salida JSON y lleva system y prompt" do
    cuerpo = Ia::ProveedorGemini.cuerpo(system: "eres coach", prompt: "genera el plan")

    expect(cuerpo.dig(:generationConfig, :responseMimeType)).to eq("application/json")
    expect(cuerpo.dig(:system_instruction, :parts, 0, :text)).to eq("eres coach")
    expect(cuerpo.dig(:contents, 0, :parts, 0, :text)).to eq("genera el plan")
  end

  it "el cuerpo de Claude lleva modelo, system y prompt" do
    cuerpo = Ia::ProveedorClaude.cuerpo(system: "eres coach", prompt: "genera el plan")

    expect(cuerpo[:model]).to eq(Ia::ProveedorClaude::MODELO)
    expect(cuerpo[:system]).to eq("eres coach")
    expect(cuerpo.dig(:messages, 0, :content)).to eq("genera el plan")
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
