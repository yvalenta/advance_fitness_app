require "rails_helper"
require "turbo/broadcastable/test_helper"

RSpec.describe PlanPersonalizado, type: :model do
  # ActionCable::TestHelper#new_broadcasts_from usa _assert_nothing_raised_or_warn
  # de ActiveSupport::Testing::Assertions; RSpec no la incluye por defecto.
  include ActiveSupport::Testing::Assertions
  include ActionCable::TestHelper
  include Turbo::Broadcastable::TestHelper

  def rutina_base
    { "dias" => [ { "dia" => "lunes", "ejercicios" => [] } ] }.freeze
  end

  def nutricion_base
    {
      "kcal_diarias" => 900,
      "comidas" => [
        { "nombre" => "Desayuno", "descripcion" => "Huevos", "kcal" => 400,
          "proteinas_g" => 30, "carbohidratos_g" => 40, "grasas_g" => 15 },
        { "nombre" => "Cena", "descripcion" => "Salmón", "kcal" => 500,
          "proteinas_g" => 35, "carbohidratos_g" => 40, "grasas_g" => 22 }
      ]
    }.freeze
  end

  def rutina_con_ejercicios
    { "dias" => [
      { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [
        { "nombre" => "Press banca", "series" => 4, "repeticiones" => "8-10", "descanso_seg" => 90 }
      ] },
      { "dia" => "martes", "enfoque" => "espalda", "ejercicios" => [] }
    ] }.freeze
  end

  def crear_plan
    PlanPersonalizado.create!(user: users(:one), rutina: rutina_base, plan_nutricional: nutricion_base)
  end

  def plan_con_rutina
    PlanPersonalizado.create!(user: users(:one), rutina: rutina_con_ejercicios, plan_nutricional: nutricion_base)
  end

  it "actualizar_ejercicio! hace merge por índice 2D y sanea números" do
    plan = plan_con_rutina
    plan.actualizar_ejercicio!(0, 0, { "nombre" => " Press inclinado ", "series" => "5", "descanso_seg" => "120" })

    ej = plan.reload.ejercicios_de(0).first
    expect(ej["nombre"]).to eq("Press inclinado")
    expect(ej["series"]).to eq(5)
    expect(ej["descanso_seg"]).to eq(120)
    expect(ej["repeticiones"]).to eq("8-10")           # no tocado
  end

  # Fase 6.4: campos del catálogo visual y de la IA personalizada
  it "sanea ejercicio_id, peso_sugerido_kg y nota_tecnica" do
    plan = plan_con_rutina
    plan.actualizar_ejercicio!(0, 0, { "ejercicio_id" => "42", "peso_sugerido_kg" => "22.5",
                                       "nota_tecnica" => " Codos pegados al torso " })

    ej = plan.reload.ejercicios_de(0).first
    expect(ej["ejercicio_id"]).to eq(42)
    expect(ej["peso_sugerido_kg"]).to eq(22.5)
    expect(ej["nota_tecnica"]).to eq("Codos pegados al torso")

    # Vacíos → nil (limpiar el vínculo no lo convierte en 0)
    plan.actualizar_ejercicio!(0, 0, { "ejercicio_id" => "", "peso_sugerido_kg" => "" })
    ej = plan.reload.ejercicios_de(0).first
    expect(ej["ejercicio_id"]).to be_nil
    expect(ej["peso_sugerido_kg"]).to be_nil
  end

  it "agregar_ejercicio! y eliminar_ejercicio! ajustan el día" do
    plan = plan_con_rutina

    expect { plan.agregar_ejercicio!(1, { "nombre" => "Remo" }) }
      .to change { plan.reload.ejercicios_de(1).size }.by(1)
    expect { plan.eliminar_ejercicio!(0, 0) }
      .to change { plan.reload.ejercicios_de(0).size }.by(-1)
  end

  it "actualizar_enfoque! cambia solo el enfoque del día" do
    plan = plan_con_rutina
    plan.actualizar_enfoque!(0, "  pecho y tríceps  ")

    expect(plan.reload.dias[0]["enfoque"]).to eq("pecho y tríceps")
    expect(plan.dias[1]["enfoque"]).to eq("espalda")
  end

  it "un día inexistente levanta error" do
    plan = plan_con_rutina
    expect { plan.agregar_ejercicio!(9, {}) }.to raise_error(IndexError)
  end

  it "publicar! da visibilidad con el staff que lo revisó" do
    plan = crear_plan
    plan.publicar!(users(:entrenador))

    expect(plan.aprobado?).to be_truthy
    expect(plan.aprobado_por).to eq(users(:entrenador))
  end

  it "un plan en generación no exige rutina ni plan nutricional" do
    plan = PlanPersonalizado.new(user: users(:one), generado_por: "ia",
                                 estado: "generando", rutina: {}, plan_nutricional: {})
    expect(plan.valid?).to be_truthy
  end

  it "ciclo de generación: generando → completar! → fallar!" do
    plan = PlanPersonalizado.create!(user: users(:one), generado_por: "ia",
                                     estado: "generando", rutina: {}, plan_nutricional: {})

    plan.completar!(rutina: rutina_base, plan_nutricional: nutricion_base, modelo: "gemini-x")
    expect(plan.borrador?).to be_truthy
    expect(plan.modelo_generacion).to eq("gemini-x")

    plan.fallar!("Gemini API 503: overloaded")
    expect(plan.fallido?).to be_truthy
    expect(plan.intentos).to eq(1)
    expect(plan.error_generacion).to match("503")
  end

  it "pendientes agrupa generando, borrador y fallido (no aprobado)" do
    generando = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "generando", rutina: {}, plan_nutricional: {})
    borrador = crear_plan
    aprobado = crear_plan.tap { |p| p.publicar!(users(:entrenador)) }

    pendientes = PlanPersonalizado.pendientes
    expect(pendientes).to include(generando)
    expect(pendientes).to include(borrador)
    expect(pendientes).not_to include(aprobado)
  end

  it "no puede estar aprobado sin aprobador" do
    plan = PlanPersonalizado.new(user: users(:one), rutina: rutina_base,
                                 plan_nutricional: nutricion_base, estado: "aprobado")
    expect(plan.valid?).to be_falsey
  end

  it "actualizar_comida! hace merge, sanea números y recalcula el total" do
    plan = crear_plan

    plan.actualizar_comida!(0, { "nombre" => " Desayuno power ", "kcal" => "520",
                                 "proteinas_g" => "35", "carbohidratos_g" => "60.5", "grasas_g" => "12" })

    comida = plan.reload.comidas.first
    expect(comida["nombre"]).to eq("Desayuno power")     # strip
    expect(comida["kcal"]).to eq(520)
    expect(comida["proteinas_g"]).to eq(35)              # entero sin .0
    expect(comida["carbohidratos_g"]).to eq(60.5)
    expect(plan.plan_nutricional["kcal_diarias"]).to eq(1020)  # 520 + 500 recalculado
  end

  it "actualizar_comida! preserva claves que el editor no maneja (receta)" do
    con_receta = nutricion_base.deep_dup
    con_receta["comidas"][0]["receta"] = { "preparacion" => "Batir." }
    plan = PlanPersonalizado.create!(user: users(:one), rutina: rutina_base, plan_nutricional: con_receta)

    plan.actualizar_comida!(0, { "kcal" => "450" })

    comida = plan.reload.comidas.first
    expect(comida.dig("receta", "preparacion")).to eq("Batir.")
    expect(comida["kcal"]).to eq(450)
  end

  it "agregar_comida! añade una comida con defaults y eliminar_comida! la quita" do
    plan = crear_plan

    expect { plan.agregar_comida! }.to change { plan.reload.comidas.size }.by(1)
    expect(plan.comidas.last["nombre"]).to eq("Nueva comida")

    expect { plan.eliminar_comida!(0) }.to change { plan.reload.comidas.size }.by(-1)
    expect(plan.comidas.first["nombre"]).to eq("Cena")
  end

  it "eliminar_comida! fuera de rango levanta RecordNotFound" do
    plan = crear_plan
    expect { plan.eliminar_comida!(99) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  # Fase 5.8: el "Mi plan" del miembro se refresca en vivo solo si el plan ya
  # está publicado (la edición del staff se ve al instante).
  it "editar un plan aprobado difunde en vivo al miembro" do
    plan = crear_plan
    plan.publicar!(users(:entrenador))

    assert_turbo_stream_broadcasts(plan, count: 1) do
      plan.actualizar_comida!(0, { "kcal" => "450" })
    end
  end

  it "editar un borrador no difunde al miembro (aún no es visible)" do
    plan = crear_plan # borrador
    assert_no_turbo_stream_broadcasts(plan) do
      plan.actualizar_comida!(0, { "kcal" => "450" })
    end
  end

  # ── Plan sugerido con la membresía (Fase 5.11) ─────────────────────────
  it "asegurar_sugerido! crea el plan reglas aprobado con membresía y objetivo" do
    ObjetivoNutricional.fijar_para(users(:one), tipo: "superavit", peso_kg: 70)

    plan = PlanPersonalizado.asegurar_sugerido!(users(:one))

    expect(plan.reglas?).to be_truthy
    expect(plan.aprobado?).to be_truthy
    expect(plan.aprobado_por).to be_nil
    expect(plan.dias.size).to eq(6)
    expect(plan.plan_nutricional).to eq({})
  end

  it "asegurar_sugerido! no crea sin objetivo ni duplica si ya hay un plan" do
    expect(PlanPersonalizado.asegurar_sugerido!(users(:one))).to be_nil # sin objetivo

    ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)
    crear_plan # ya existe un plan del miembro
    expect {
      expect(PlanPersonalizado.asegurar_sugerido!(users(:one))).to be_nil
    }.not_to change(PlanPersonalizado, :count)
  end

  it "asegurar_sugerido! no crea sin membresía activa" do
    ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)
    users(:one).membresia.update!(estado: "vencida")

    expect(PlanPersonalizado.asegurar_sugerido!(users(:one))).to be_nil
  end

  it "aplicar_sesion! reemplaza enfoque y ejercicios del día con el músculo" do
    plan = plan_con_rutina
    plantillas = [ plantillas_ejercicio(:press_banca) ]

    plan.aplicar_sesion!(0, "pecho", plantillas)

    dia = plan.reload.dias[0]
    expect(dia["enfoque"]).to eq("Pecho")
    expect(dia["ejercicios"].map { |e| e["nombre"] }).to eq([ "Press de banca con barra" ])
    expect(plan.dias[1]["enfoque"]).to eq("espalda") # otro día intacto
  end

  it "aplicar_sesion! sin plantillas levanta RecordNotFound" do
    plan = plan_con_rutina
    expect { plan.aplicar_sesion!(0, "gluteo", []) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
