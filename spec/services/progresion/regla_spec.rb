require "rails_helper"

RSpec.describe Progresion::Regla do
  let(:user) { users(:one) }
  let(:ejercicio) do
    Ejercicio.create!(dataset_id: "test-progresion", nombre: "Press de banca", nombre_en: "Bench press",
                      nombre_normalizado: "press de banca", categoria: "fuerza", musculo: "pecho")
  end
  let(:rutina) do
    { "dias" => [
      { "dia" => "lunes", "ejercicios" => [
        { "uid" => "u1", "nombre" => "Press de banca", "series" => 2, "repeticiones" => "8-10",
          "peso_sugerido_kg" => 60, "ejercicio_id" => ejercicio.id }
      ] }
    ] }
  end
  let(:plan) { PlanPersonalizado.create!(user: user, generado_por: "reglas", estado: "aprobado", rutina: rutina, plan_nutricional: {}) }
  # La regla evalúa la prescripción de ESA fecha (Nota 27g): el lunes en
  # curso, que es el día que trae la rutina.
  let(:fecha) { Date.current.beginning_of_week }

  def registrar_serie(numero, reps:, peso_kg: 60, en: fecha)
    registro = RegistroEntrenamiento.find_or_create_by!(user: user, fecha: en)
    registro.detalles.create!(ejercicio: ejercicio, serie: numero, repeticiones: reps, peso_kg: peso_kg)
  end

  def evaluar!(en: fecha)
    described_class.evaluar_tras_serie!(user: user, uid: "u1", fecha: en, ejercicio: ejercicio)
  end

  # El piso (8 de "8-10"), no el tope: el modo sesión SIEMPRE registra el
  # piso del rango sin pedir que el miembro escriba nada (Fase 18l) — exigir
  # el tope dejaría la regla inalcanzable en la práctica.
  it "sube el peso sugerido cuando TODAS las series completan el piso del rango" do
    plan
    registrar_serie(1, reps: 8)
    registrar_serie(2, reps: 8)

    evaluar!

    entrada = plan.reload.ejercicios_de(0).first
    expect(entrada["peso_sugerido_kg"]).to eq(62.5)
  end

  it "no sube si alguna serie quedó por debajo del piso" do
    plan
    registrar_serie(1, reps: 8)
    registrar_serie(2, reps: 6) # no llegó al piso (8)

    evaluar!

    expect(plan.reload.ejercicios_de(0).first["peso_sugerido_kg"]).to eq(60)
  end

  it "no sube si aún faltan series del día (evalúa antes de tiempo)" do
    plan
    registrar_serie(1, reps: 10) # solo 1 de 2 series

    evaluar!

    expect(plan.reload.ejercicios_de(0).first["peso_sugerido_kg"]).to eq(60)
  end

  it "no sube ejercicios de peso corporal (sin peso_kg)" do
    plan
    registrar_serie(1, reps: 10, peso_kg: nil)
    registrar_serie(2, reps: 10, peso_kg: nil)

    evaluar!

    expect(plan.reload.ejercicios_de(0).first["peso_sugerido_kg"]).to eq(60)
  end

  it "es idempotente: reintentar el POST de la última serie no progresa dos veces" do
    plan
    registrar_serie(1, reps: 10)
    registrar_serie(2, reps: 10)

    evaluar!
    evaluar! # reintento (misma info, el peso sugerido ya no es 60)

    expect(plan.reload.ejercicios_de(0).first["peso_sugerido_kg"]).to eq(62.5)
  end

  it "no progresa ejercicios por tiempo ni en superserie" do
    plan.update!(rutina: { "dias" => [
      { "dia" => "lunes", "ejercicios" => [
        { "uid" => "u1", "nombre" => "Plancha", "series" => 1, "repeticiones" => "10",
          "peso_sugerido_kg" => 60, "ejercicio_id" => ejercicio.id, "tipo" => "tiempo" }
      ] }
    ] })
    registrar_serie(1, reps: 10)

    evaluar!

    expect(plan.reload.ejercicios_de(0).first["peso_sugerido_kg"]).to eq(60)
  end

  it "propaga el incremento a TODAS las apariciones del uid (semana materializada incluida)" do
    plan.update!(rutina: {
      "version" => 2,
      "mesociclo" => { "nombre" => "x", "semanas_total" => 2, "inicio" => fecha.iso8601, "progresion" => "lineal" },
      "dias" => [
        { "dia" => "lunes", "ejercicios" => [
          { "uid" => "u1", "nombre" => "Press de banca", "series" => 2, "repeticiones" => "8-10",
            "peso_sugerido_kg" => 60, "ejercicio_id" => ejercicio.id }
        ] }
      ],
      "semanas" => [
        { "numero" => 1, "etiqueta" => "S1", "descarga" => false, "ajuste" => { "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 }, "dias" => nil },
        { "numero" => 2, "etiqueta" => "S2", "descarga" => false, "ajuste" => { "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 },
          "dias" => [ { "dia" => "lunes", "ejercicios" => [
            { "uid" => "u1", "nombre" => "Press de banca", "series" => 2, "repeticiones" => "8-10",
              "peso_sugerido_kg" => 60, "ejercicio_id" => ejercicio.id }
          ] } ] }
      ]
    })
    registrar_serie(1, reps: 10)
    registrar_serie(2, reps: 10)

    evaluar!

    plan.reload
    expect(plan.dias(semana: 1).first["ejercicios"].first["peso_sugerido_kg"]).to eq(62.5)
    expect(plan.semana(2)["dias"].first["ejercicios"].first["peso_sugerido_kg"]).to eq(62.5)
  end

  # El uid se busca en el día de ESA fecha, no en toda la rutina: series
  # registradas un miércoles no se evalúan contra el ejercicio del lunes.
  it "no evalúa si el uid no está en el día programado para esa fecha" do
    plan
    miercoles = fecha + 2
    registrar_serie(1, reps: 8, en: miercoles)
    registrar_serie(2, reps: 8, en: miercoles)

    evaluar!(en: miercoles)

    expect(plan.reload.ejercicios_de(0).first["peso_sugerido_kg"]).to eq(60)
  end

  # La compuerta del ciclo no depende de que el día quede más liviano que la
  # base: una semana de 1.2 × lútea 0.9 = 1.08 levanta MÁS que la base y
  # aun así una fase que recorta no cuenta como progreso.
  it "no progresa en una fase del ciclo que recorta, aunque la semana compense la carga" do
    plan.update!(rutina: rutina.merge(
      "version" => 2,
      "mesociclo" => { "nombre" => "x", "semanas_total" => 1, "inicio" => fecha.iso8601, "progresion" => "lineal" },
      "semanas" => [ { "numero" => 1, "etiqueta" => "Pico", "descarga" => false, "dias" => nil,
                       "ajuste" => { "series_delta" => 0, "peso_factor" => 1.2, "reps_delta" => 0 } } ]
    ))
    user.consentimientos.create!(tipo: "ciclo_menstrual", accion: "otorgado", version_texto: "ciclo-v1")
    CicloMenstrual.create!(user: user, creado_por: user, fecha_inicio: fecha - 19) # día 20: lútea
    expect(Ciclo::Fase.para(user, fecha)).to eq(:lutea)
    registrar_serie(1, reps: 8, peso_kg: 65) # 60 × 1.08 = 64.8 → 65
    registrar_serie(2, reps: 8, peso_kg: 65)

    evaluar!

    expect(plan.reload.ejercicios_de(0).first["peso_sugerido_kg"]).to eq(60)
  end

  # La marca manda aunque los números no bajen: una descarga de volumen o
  # de técnica al 1.0 tampoco es evidencia de progreso.
  it "no progresa en una semana marcada como descarga aunque su ajuste sea identidad" do
    plan.update!(rutina: rutina.merge(
      "version" => 2,
      "mesociclo" => { "nombre" => "x", "semanas_total" => 1, "inicio" => fecha.iso8601, "progresion" => "lineal" },
      "semanas" => [ { "numero" => 1, "etiqueta" => "Descarga", "descarga" => true, "dias" => nil,
                       "ajuste" => { "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 } } ]
    ))
    registrar_serie(1, reps: 8)
    registrar_serie(2, reps: 8)

    evaluar!

    expect(plan.reload.ejercicios_de(0).first["peso_sugerido_kg"]).to eq(60)
  end
end
