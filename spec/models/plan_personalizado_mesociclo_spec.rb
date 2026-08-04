require "rails_helper"

# Contrato `rutina` v2 con mesociclo (Fase 14.7): lectura tolerante v1,
# resolución semanal, copy-on-write y arranque del calendario.
RSpec.describe PlanPersonalizado, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  def nutricion
    { "kcal_diarias" => 500, "comidas" => [ { "nombre" => "Almuerzo", "kcal" => 500 } ] }
  end

  def dias_base
    [ { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [
      { "uid" => "u-press", "nombre" => "Press banca", "series" => 4, "repeticiones" => "8-10",
        "descanso_seg" => 90, "peso_sugerido_kg" => 60 }
    ] },
      { "dia" => "jueves", "enfoque" => "pierna", "ejercicios" => [
        { "uid" => "u-sent", "nombre" => "Sentadilla", "series" => 3, "repeticiones" => "al fallo" }
      ] } ]
  end

  def rutina_v2(inicio: "2026-08-03", semanas_total: 4)
    { "version" => 2,
      "mesociclo" => { "nombre" => "Hipertrofia base", "semanas_total" => semanas_total,
                       "inicio" => inicio, "progresion" => "lineal" },
      "dias" => dias_base,
      "semanas" => (1..semanas_total).map do |numero|
        { "numero" => numero, "etiqueta" => "Semana #{numero}", "descarga" => false,
          "ajuste" => { "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 },
          "dias" => nil }
      end }
  end

  def plan_v1
    PlanPersonalizado.create!(user: users(:one), rutina: { "dias" => dias_base }, plan_nutricional: nutricion)
  end

  def plan_v2(rutina: rutina_v2())
    PlanPersonalizado.create!(user: users(:one), rutina: rutina, plan_nutricional: nutricion)
  end

  describe "lectura tolerante v1" do
    it "un plan sin version se ve como mesociclo de 1 semana identidad, sin escribir nada" do
      plan = plan_v1

      expect(plan.semanas.size).to eq(1)
      expect(plan.semana(1)["ajuste"]).to eq({ "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 })
      expect(plan.semana(1)["dias"]).to be_nil
      expect(plan.semanas_total).to eq(1)
      expect(plan.semana_actual).to eq(1)
      expect(plan.semana_materializada?(1)).to be_falsey
      expect(plan.dias(semana: 1)).to eq(dias_base)

      expect(plan.reload.rutina).not_to have_key("version") # cero escritura desde la lectura
    end
  end

  describe "#semana_actual y #mesociclo_completado?" do
    it "siguen el calendario con clamp a 1..semanas_total" do
      plan = plan_v2 # inicio lunes 2026-08-03, 4 semanas

      travel_to(Date.new(2026, 8, 12)) do # miércoles de la semana 2
        expect(plan.semana_actual).to eq(2)
        expect(plan.mesociclo_completado?).to be_falsey
      end

      travel_to(Date.new(2026, 7, 30)) do # antes del inicio → clamp abajo
        expect(plan.semana_actual).to eq(1)
        expect(plan.mesociclo_completado?).to be_falsey
      end

      travel_to(Date.new(2026, 9, 10)) do # semana 6 real → clamp a la última
        expect(plan.semana_actual).to eq(4)
        expect(plan.mesociclo_completado?).to be_truthy
      end
    end
  end

  describe "#materializar_semana! / #desmaterializar_semana!" do
    def plan_con_ajuste
      rutina = rutina_v2
      rutina["semanas"][1]["ajuste"] = { "series_delta" => 1, "peso_factor" => 1.1, "reps_delta" => 1 }
      plan_v2(rutina: rutina)
    end

    it "congela la semana con su ajuste horneado, conservando el uid (mismo ejercicio que la base)" do
      plan = plan_con_ajuste
      plan.materializar_semana!(2)

      expect(plan.semana_materializada?(2)).to be_truthy
      ej = plan.reload.semana(2)["dias"].first["ejercicios"].first
      expect(ej["series"]).to eq(5)            # 4 + 1 horneado
      expect(ej["peso_sugerido_kg"]).to eq(66) # 60 × 1.1 horneado
      expect(ej["repeticiones"]).to eq("9-11")
      # El uid NO cambia al materializar: base y semana comparten uid porque
      # son el MISMO ejercicio a lo largo del mesociclo, no una copia nueva.
      expect(ej["uid"]).to eq("u-press")
      expect(plan.dias.first["ejercicios"].first["uid"]).to eq("u-press")

      # La base y las demás semanas quedan intactas
      expect(plan.dias.first["ejercicios"].first["series"]).to eq(4)
      expect(plan.semana(1)["dias"]).to be_nil
    end

    it "es idempotente y una semana inexistente levanta RecordNotFound" do
      plan = plan_con_ajuste
      plan.materializar_semana!(2)
      expect { plan.materializar_semana!(2) }.not_to change { plan.reload.rutina }
      expect { plan.materializar_semana!(9) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "desmaterializar vuelve a la herencia base + ajuste, descartando ediciones" do
      plan = plan_con_ajuste
      plan.actualizar_ejercicio!(0, 0, { "nombre" => "Press inclinado" }, semana: 2)
      expect(plan.ejercicios_de(0, semana: 2).first["nombre"]).to eq("Press inclinado")

      plan.desmaterializar_semana!(2)

      expect(plan.semana_materializada?(2)).to be_falsey
      ej = plan.ejercicios_de(0, semana: 2).first
      expect(ej["nombre"]).to eq("Press banca") # edición descartada
      expect(ej["series"]).to eq(5)             # el ajuste vuelve a regir
    end
  end

  describe "#actualizar_ajuste_semana!" do
    it "sanea solo CAMPOS_AJUSTE con clamps y hace merge sin pisar lo demás" do
      plan = plan_v2
      plan.actualizar_ajuste_semana!(2, { "peso_factor" => "0.85", "series_delta" => "1" })
      plan.actualizar_ajuste_semana!(2, { "reps_delta" => "-9", "hack" => "x" })

      ajuste = plan.reload.semana(2)["ajuste"]
      expect(ajuste["peso_factor"]).to eq(0.85) # el segundo merge no lo pisó
      expect(ajuste["series_delta"]).to eq(1)
      expect(ajuste["reps_delta"]).to eq(-2)    # clamp -2..2
      expect(ajuste).not_to have_key("hack")
    end

    it "aplica los clamps de factor (0.5..1.5) y deltas (-2..2)" do
      plan = plan_v2
      plan.actualizar_ajuste_semana!(3, { "peso_factor" => "9", "series_delta" => "7" })

      ajuste = plan.reload.semana(3)["ajuste"]
      expect(ajuste["peso_factor"]).to eq(1.5)
      expect(ajuste["series_delta"]).to eq(2)
    end
  end

  describe "mutadores con semana:" do
    it "materializan la semana y editan solo su copia (base intacta)" do
      plan = plan_v2
      plan.eliminar_ejercicio!(0, 0, semana: 3)

      expect(plan.semana_materializada?(3)).to be_truthy
      expect(plan.ejercicios_de(0, semana: 3)).to be_empty
      expect(plan.ejercicios_de(0).size).to eq(1)            # base intacta
      expect(plan.ejercicios_de(0, semana: 1).size).to eq(1) # otra semana intacta
    end

    it "sobre un plan v1 la primera mutación semanal asciende el contrato a v2" do
      plan = plan_v1
      plan.actualizar_enfoque!(0, "pecho y tríceps", semana: 1)

      rutina = plan.reload.rutina
      expect(rutina["version"]).to eq(2)
      expect(plan.semana_materializada?(1)).to be_truthy
      expect(plan.dias(semana: 1).first["enfoque"]).to eq("pecho y tríceps")
      expect(plan.dias.first["enfoque"]).to eq("pecho") # plantilla base intacta
    end
  end

  describe "arranque del calendario" do
    it "publicar! fija mesociclo['inicio'] al lunes de esa semana en un plan v2" do
      plan = plan_v2(rutina: rutina_v2(inicio: "2026-01-05"))
      # Publicar cambia la rutina (inicio) → difunde al miembro; ese render
      # asume el request del staff (Current.user presente), como en producción.
      Current.session = users(:entrenador).sessions.create!

      travel_to(Date.new(2026, 8, 5)) { plan.publicar!(users(:entrenador)) } # miércoles

      expect(plan.reload.rutina.dig("mesociclo", "inicio")).to eq("2026-08-03")
      expect(plan.aprobado?).to be_truthy
    end

    it "publicar! deja una rutina v1 tal cual" do
      plan = plan_v1
      plan.publicar!(users(:entrenador))

      expect(plan.reload.rutina).not_to have_key("mesociclo")
      expect(plan.aprobado?).to be_truthy
    end

    it "asegurar_sugerido! fija el inicio si el generador emite contrato v2" do
      ObjetivoNutricional.fijar_para(users(:one), tipo: "superavit", peso_kg: 70)
      allow(GeneradorPlanBasico).to receive(:para).and_return(rutina_v2(inicio: nil))

      plan = travel_to(Date.new(2026, 8, 6)) { PlanPersonalizado.asegurar_sugerido!(users(:one)) }

      expect(plan.rutina.dig("mesociclo", "inicio")).to eq("2026-08-03")
    end
  end
end
