require "rails_helper"

# Fase 14.4: la card de nutrición de Mi plan agrupa las comidas en el grid
# 2×2 por tipo (Desayuno/Almuerzo/Cena/Snacks) con "Recomendado" = kcal del
# plan para ese tipo. La normalización vive en la vista: un tipo ausente o
# fuera de PlantillaComida::TIPOS cae al bucket "Otros".
RSpec.describe "NutricionPorTipo", type: :request do
  let(:rutina) { { "dias" => [ { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [] } ] } }

  def plan_con(comidas)
    PlanPersonalizado.create!(
      user: users(:one), generado_por: "entrenador", estado: "aprobado",
      aprobado_por: users(:entrenador), rutina: rutina,
      plan_nutricional: { "kcal_diarias" => comidas.sum { |c| c["kcal"].to_i }, "comidas" => comidas })
  end

  it "agrupa las comidas por tipo con el recomendado del tipo" do
    plan_con([
      { "nombre" => "Avena con huevos", "descripcion" => "Avena, huevos y fruta", "kcal" => 450,
        "proteinas_g" => 30, "carbohidratos_g" => 50, "grasas_g" => 12, "tipo" => "desayuno" },
      { "nombre" => "Pollo con arroz", "descripcion" => "Pechuga, arroz y ensalada", "kcal" => 700,
        "proteinas_g" => 45, "carbohidratos_g" => 80, "grasas_g" => 18, "tipo" => "almuerzo" },
      { "nombre" => "Yogur griego", "descripcion" => "Yogur con almendras", "kcal" => 200,
        "proteinas_g" => 15, "carbohidratos_g" => 20, "grasas_g" => 5, "tipo" => "snack" }
    ])
    sign_in_as users(:one)

    get mi_plan_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Desayuno", "Almuerzo", "Cena", "Snacks")
    expect(response.body).to include("Recomendado: 450 kcal", "Recomendado: 700 kcal", "Recomendado: 200 kcal")
    # La cena no tiene comidas pero su card del grid 2×2 aparece igual
    expect(response.body).to include("Sin comidas de este tipo")
    # Sin comidas fuera de los cuatro tipos, no aparece el bucket Otros
    expect(response.body).not_to include("Otros")
    # El checkbox lleva tipo y macros para el registro del consumo (Fase 14.4)
    assert_select "input[data-tipo='desayuno'][data-proteinas='30'][data-carbohidratos='50'][data-grasas='12']"
    # Y el form del registro expone los hidden fields de macros
    assert_select "input[name=?]", "registro_caloria[proteinas_g]"
    assert_select "input[name=?]", "registro_caloria[grasas_g]"
  end

  it "tipo ausente o inválido cae al bucket Otros" do
    plan_con([
      { "nombre" => "Batido", "descripcion" => "Batido de proteína", "kcal" => 300,
        "proteinas_g" => 25, "carbohidratos_g" => 30, "grasas_g" => 8 },
      { "nombre" => "Arepa", "descripcion" => "Arepa con queso", "kcal" => 250,
        "proteinas_g" => 8, "carbohidratos_g" => 40, "grasas_g" => 6, "tipo" => "brunch" }
    ])
    sign_in_as users(:one)

    get mi_plan_path

    expect(response.body).to include("Otros")
    expect(response.body).to include("Recomendado: 550 kcal") # 300 + 250 del bucket
    assert_select "input[data-tipo='otros']", count: 2
  end

  it "el editor propio ofrece el select de tipo por comida" do
    plan_con([ { "nombre" => "Batido", "descripcion" => "Batido de proteína", "kcal" => 300,
                 "proteinas_g" => 25, "carbohidratos_g" => 30, "grasas_g" => 8, "tipo" => "desayuno" } ])
    sign_in_as users(:one)

    get mi_plan_path

    assert_select "select[name='comida[tipo]'] option[value='desayuno'][selected]"
    assert_select "select[name='comida[tipo]'] option[value='']", text: "Sin clasificar"
  end
end
