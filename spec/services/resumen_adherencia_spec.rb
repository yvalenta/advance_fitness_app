require "rails_helper"

RSpec.describe ResumenAdherencia, type: :model do
  before { @user = users(:one) }

  def registrar(fecha, ejercicios)
    RegistroEntrenamiento.create!(user: @user, fecha: fecha, ejercicios: ejercicios)
  end

  it "agrega por nombre entre semanas y separa las novedades" do
    lunes = Date.current.beginning_of_week
    registrar(lunes, { "0" => { "hecho" => true, "nombre" => "Press banca" },
                       "1" => { "hecho" => false, "nombre" => "Dominadas" },
                       "novedad" => "me dolió el hombro" })
    registrar(lunes - 1.week, { "0" => { "hecho" => true, "nombre" => "Press banca" } })

    resumen = ResumenAdherencia.para(@user)

    expect(resumen[:pct_global]).to eq(67)
    press = resumen[:por_ejercicio].find { |e| e[:nombre] == "Press banca" }
    expect(press).to eq({ nombre: "Press banca", hechos: 2, total: 2 })
    expect(resumen[:novedades]).to eq([ "me dolió el hombro" ])
  end

  it "sin registros devuelve nil y fuera de rango no cuenta" do
    expect(ResumenAdherencia.para(@user)).to be_nil

    registrar(Date.current - 10.weeks, { "0" => { "hecho" => true, "nombre" => "Viejo" } })
    expect(ResumenAdherencia.para(@user, semanas: 4)).to be_nil
  end

  # Fase 14.6: los registros nuevos anclan por uid bajo "items" (v2); los
  # viejos quedan como hechos históricos en v1. El resumen entiende ambos y
  # sigue agrupando por NOMBRE. Lo archivado bajo "legacy" no se cuenta
  # (doble conteo con el re-marcado v2).
  it "mezcla registros v1 y v2 en el mismo resumen" do
    lunes = Date.current.beginning_of_week
    registrar(lunes - 1.week, { "0" => { "hecho" => true, "nombre" => "Press banca" },
                                "novedad" => "banca ocupada" })
    registrar(lunes, { "version" => 2, "novedad" => "hombro al 100", "plan_id" => 7,
                       "legacy" => { "0" => { "hecho" => false, "nombre" => "Press banca" } },
                       "items" => {
                         "uidpress01" => { "hecho" => true, "nombre" => "Press banca", "dia" => 0, "indice" => 0 },
                         "uiddomin02" => { "hecho" => false, "nombre" => "Dominadas", "dia" => 0, "indice" => 1 },
                         "uidsinnom3" => { "hecho" => true, "dia" => 0, "indice" => 4 }
                       } })

    resumen = ResumenAdherencia.para(@user)

    press = resumen[:por_ejercicio].find { |e| e[:nombre] == "Press banca" }
    expect(press).to eq({ nombre: "Press banca", hechos: 2, total: 2 })  # v1 + v2, sin doble conteo del legacy
    expect(resumen[:por_ejercicio].find { |e| e[:nombre] == "Dominadas" }).to eq({ nombre: "Dominadas", hechos: 0, total: 1 })
    # Sin nombre usa el indice histórico del item, no la clave uid
    expect(resumen[:por_ejercicio].find { |e| e[:nombre] == "Ejercicio 5" }).to be_present
    expect(resumen[:pct_global]).to eq(75)  # 3 de 4
    expect(resumen[:novedades]).to eq([ "banca ocupada", "hombro al 100" ])
  end

  it "ignora claves no numéricas y limita las novedades a 5" do
    lunes = Date.current.beginning_of_week
    7.times do |i|
      registrar(lunes - i.days, { "novedad" => "nota #{i}", "basura" => { "hecho" => true } })
    end

    resumen = ResumenAdherencia.para(@user)
    expect(resumen[:novedades].size).to eq(5)
    expect(resumen[:por_ejercicio]).to be_empty
  end

  # ── Etapa 14.10: adherencia por semana del mesociclo ─────────────────────
  describe "por_semana con plan vigente" do
    def semanas_v2
      [ { "numero" => 1, "etiqueta" => "Adaptación", "descarga" => false },
        { "numero" => 2, "etiqueta" => "Acumulación", "descarga" => false },
        { "numero" => 3, "etiqueta" => "Intensificación", "descarga" => false },
        { "numero" => 4, "etiqueta" => "Descarga", "descarga" => true } ]
    end

    # Plan aprobado creado hace `hace` (su ciclo arranca ese lunes); con
    # semanas: nil la rutina no lleva "semanas" → plan v1 (semana identidad).
    def plan_vigente(semanas: semanas_v2, hace: 2.weeks)
      rutina = { "dias" => [ { "dia" => "lunes", "ejercicios" => [] } ] }
      rutina["semanas"] = semanas if semanas
      plan = PlanPersonalizado.new(user: @user, generado_por: "reglas", estado: "aprobado",
                                   rutina: rutina, plan_nutricional: {})
      plan.created_at = hace.ago
      plan.save!
      plan
    end

    it "agrupa por semana del ciclo y aparta lo fuera del mesociclo" do
      plan = plan_vigente # inicio: lunes de hace 2 semanas → hoy es semana 3
      inicio = Date.current.beginning_of_week - 2.weeks
      registrar(inicio - 2.days, { "0" => { "hecho" => true, "nombre" => "Viejo" } }) # previo al plan
      registrar(inicio, { "0" => { "hecho" => true, "nombre" => "Press banca" },
                          "1" => { "hecho" => false, "nombre" => "Dominadas" } })
      registrar(inicio + 1.week, { "0" => { "hecho" => true, "nombre" => "Press banca" } })

      resumen = ResumenAdherencia.para(@user, plan: plan)

      expect(resumen[:por_semana]).to eq([
        { numero: 1, etiqueta: "Adaptación", descarga: false, hechos: 1, total: 2, porcentaje: 50 },
        { numero: 2, etiqueta: "Acumulación", descarga: false, hechos: 1, total: 1, porcentaje: 100 }
      ])
      expect(resumen[:fuera_de_ciclo]).to eq({ hechos: 1, total: 1, porcentaje: 100 })
    end

    it "plan v1: todo lo del ciclo cae en la semana identidad y no hay narrativa" do
      plan = plan_vigente(semanas: nil, hace: 0.days) # ciclo = solo esta semana
      registrar(Date.current, { "0" => { "hecho" => true, "nombre" => "Sentadilla" } })
      registrar(Date.current.beginning_of_week - 1.week,
                { "0" => { "hecho" => false, "nombre" => "Sentadilla" } })

      resumen = ResumenAdherencia.para(@user, plan: plan)

      expect(resumen[:por_semana].size).to eq(1)
      expect(resumen[:por_semana].first).to include(numero: 1, hechos: 1, total: 1, porcentaje: 100)
      expect(resumen[:fuera_de_ciclo]).to include(hechos: 0, total: 1)
      expect(resumen[:contexto_ciclo]).to be_nil
    end

    it "cuenta registros jsonb v1 y v2 mezclados sin tocar por_ejercicio" do
      plan = plan_vigente
      inicio = Date.current.beginning_of_week - 2.weeks
      registrar(inicio, { "0" => { "hecho" => true, "nombre" => "Press banca" } }) # v1
      registrar(inicio + 1.day, { "s1_e0" => { "hecho" => true, "nombre" => "Remo" },
                                  "s1_e1" => { "hecho" => false, "nombre" => "Curl" },
                                  "novedad" => "banda ocupada" })                  # v2

      resumen = ResumenAdherencia.para(@user, plan: plan)

      semana1 = resumen[:por_semana].find { |s| s[:numero] == 1 }
      expect(semana1).to include(hechos: 2, total: 3, porcentaje: 67)
      expect(resumen[:fuera_de_ciclo]).to be_nil
    end

    it "narra la posición del ciclo para el prompt de regeneración" do
      plan = plan_vigente # hoy = semana 3 de 4 y la 4 es descarga
      registrar(Date.current, { "0" => { "hecho" => true, "nombre" => "Press banca" } })

      resumen = ResumenAdherencia.para(@user, plan: plan)

      expect(resumen[:contexto_ciclo])
        .to eq("Va en la semana 3 de 4 (Intensificación); la próxima es descarga.")
    end

    it "cuando el mesociclo ya terminó lo dice y nada cae en semanas" do
      plan = plan_vigente(hace: 5.weeks) # ciclo de 4 semanas ya vencido
      registrar(Date.current, { "0" => { "hecho" => true, "nombre" => "Press banca" } })

      resumen = ResumenAdherencia.para(@user, plan: plan)

      expect(resumen[:contexto_ciclo]).to match(/ya terminó/)
      expect(resumen[:por_semana]).to be_empty
      expect(resumen[:fuera_de_ciclo]).to include(total: 1)
    end

    it "sin plan el resumen conserva su forma clásica" do
      registrar(Date.current, { "0" => { "hecho" => true, "nombre" => "Press banca" } })

      resumen = ResumenAdherencia.para(@user)

      expect(resumen).not_to have_key(:por_semana)
      expect(resumen).not_to have_key(:contexto_ciclo)
    end
  end
end
