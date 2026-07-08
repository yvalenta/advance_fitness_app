require "test_helper"

class PlanPersonalizadoTest < ActiveSupport::TestCase
  RUTINA = { "dias" => [ { "dia" => "lunes", "ejercicios" => [] } ] }.freeze
  NUTRICION = {
    "kcal_diarias" => 900,
    "comidas" => [
      { "nombre" => "Desayuno", "descripcion" => "Huevos", "kcal" => 400,
        "proteinas_g" => 30, "carbohidratos_g" => 40, "grasas_g" => 15 },
      { "nombre" => "Cena", "descripcion" => "Salmón", "kcal" => 500,
        "proteinas_g" => 35, "carbohidratos_g" => 40, "grasas_g" => 22 }
    ]
  }.freeze

  def crear_plan
    PlanPersonalizado.create!(user: users(:one), rutina: RUTINA, plan_nutricional: NUTRICION)
  end

  RUTINA_CON_EJERCICIOS = { "dias" => [
    { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [
      { "nombre" => "Press banca", "series" => 4, "repeticiones" => "8-10", "descanso_seg" => 90 }
    ] },
    { "dia" => "martes", "enfoque" => "espalda", "ejercicios" => [] }
  ] }.freeze

  def plan_con_rutina
    PlanPersonalizado.create!(user: users(:one), rutina: RUTINA_CON_EJERCICIOS, plan_nutricional: NUTRICION)
  end

  test "actualizar_ejercicio! hace merge por índice 2D y sanea números" do
    plan = plan_con_rutina
    plan.actualizar_ejercicio!(0, 0, { "nombre" => " Press inclinado ", "series" => "5", "descanso_seg" => "120" })

    ej = plan.reload.ejercicios_de(0).first
    assert_equal "Press inclinado", ej["nombre"]
    assert_equal 5, ej["series"]
    assert_equal 120, ej["descanso_seg"]
    assert_equal "8-10", ej["repeticiones"]           # no tocado
  end

  test "agregar_ejercicio! y eliminar_ejercicio! ajustan el día" do
    plan = plan_con_rutina

    assert_difference -> { plan.reload.ejercicios_de(1).size }, 1 do
      plan.agregar_ejercicio!(1, { "nombre" => "Remo" })
    end
    assert_difference -> { plan.reload.ejercicios_de(0).size }, -1 do
      plan.eliminar_ejercicio!(0, 0)
    end
  end

  test "actualizar_enfoque! cambia solo el enfoque del día" do
    plan = plan_con_rutina
    plan.actualizar_enfoque!(0, "  pecho y tríceps  ")

    assert_equal "pecho y tríceps", plan.reload.dias[0]["enfoque"]
    assert_equal "espalda", plan.dias[1]["enfoque"]
  end

  test "un día inexistente levanta error" do
    plan = plan_con_rutina
    assert_raises(IndexError) { plan.agregar_ejercicio!(9, {}) }
  end

  test "publicar! da visibilidad con el staff que lo revisó" do
    plan = crear_plan
    plan.publicar!(users(:entrenador))

    assert plan.aprobado?
    assert_equal users(:entrenador), plan.aprobado_por
  end

  test "un plan en generación no exige rutina ni plan nutricional" do
    plan = PlanPersonalizado.new(user: users(:one), generado_por: "ia",
                                 estado: "generando", rutina: {}, plan_nutricional: {})
    assert plan.valid?
  end

  test "ciclo de generación: generando → completar! → fallar!" do
    plan = PlanPersonalizado.create!(user: users(:one), generado_por: "ia",
                                     estado: "generando", rutina: {}, plan_nutricional: {})

    plan.completar!(rutina: RUTINA, plan_nutricional: NUTRICION, modelo: "gemini-x")
    assert plan.borrador?
    assert_equal "gemini-x", plan.modelo_generacion

    plan.fallar!("Gemini API 503: overloaded")
    assert plan.fallido?
    assert_equal 1, plan.intentos
    assert_match "503", plan.error_generacion
  end

  test "pendientes agrupa generando, borrador y fallido (no aprobado)" do
    generando = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "generando", rutina: {}, plan_nutricional: {})
    borrador = crear_plan
    aprobado = crear_plan.tap { |p| p.publicar!(users(:entrenador)) }

    pendientes = PlanPersonalizado.pendientes
    assert_includes pendientes, generando
    assert_includes pendientes, borrador
    assert_not_includes pendientes, aprobado
  end

  test "no puede estar aprobado sin aprobador" do
    plan = PlanPersonalizado.new(user: users(:one), rutina: RUTINA,
                                 plan_nutricional: NUTRICION, estado: "aprobado")
    assert_not plan.valid?
  end

  test "actualizar_comida! hace merge, sanea números y recalcula el total" do
    plan = crear_plan

    plan.actualizar_comida!(0, { "nombre" => " Desayuno power ", "kcal" => "520",
                                 "proteinas_g" => "35", "carbohidratos_g" => "60.5", "grasas_g" => "12" })

    comida = plan.reload.comidas.first
    assert_equal "Desayuno power", comida["nombre"]     # strip
    assert_equal 520, comida["kcal"]
    assert_equal 35, comida["proteinas_g"]              # entero sin .0
    assert_equal 60.5, comida["carbohidratos_g"]
    assert_equal 1020, plan.plan_nutricional["kcal_diarias"]  # 520 + 500 recalculado
  end

  test "actualizar_comida! preserva claves que el editor no maneja (receta)" do
    con_receta = NUTRICION.deep_dup
    con_receta["comidas"][0]["receta"] = { "preparacion" => "Batir." }
    plan = PlanPersonalizado.create!(user: users(:one), rutina: RUTINA, plan_nutricional: con_receta)

    plan.actualizar_comida!(0, { "kcal" => "450" })

    comida = plan.reload.comidas.first
    assert_equal "Batir.", comida.dig("receta", "preparacion")
    assert_equal 450, comida["kcal"]
  end

  test "agregar_comida! añade una comida con defaults y eliminar_comida! la quita" do
    plan = crear_plan

    assert_difference -> { plan.reload.comidas.size }, 1 do
      plan.agregar_comida!
    end
    assert_equal "Nueva comida", plan.comidas.last["nombre"]

    assert_difference -> { plan.reload.comidas.size }, -1 do
      plan.eliminar_comida!(0)
    end
    assert_equal "Cena", plan.comidas.first["nombre"]
  end

  test "eliminar_comida! fuera de rango levanta RecordNotFound" do
    plan = crear_plan
    assert_raises(ActiveRecord::RecordNotFound) { plan.eliminar_comida!(99) }
  end
end
