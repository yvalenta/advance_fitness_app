require "rails_helper"

RSpec.describe "PlanesPersonalizados", type: :request do
  # Fase 5.11: con membresía activa y sin objetivo, Mi plan pregunta la meta.
  it "miembro con membresía activa sin objetivo ve el prompt de meta" do
    sign_in_as users(:one)

    get mi_plan_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("¿Cuál es tu meta?")
    expect(users(:one).plan_aprobado).to be_nil
  end

  # Fase 5.11: con objetivo, el plan sugerido se crea (on-demand) y es editable
  # por su dueño, con seguimiento inline en la rutina.
  it "con objetivo se crea el plan sugerido editable con seguimiento inline" do
    ObjetivoNutricional.fijar_para(users(:one), tipo: "superavit", peso_kg: 70)
    sign_in_as users(:one)

    get mi_plan_path

    expect(response).to have_http_status(:success)
    plan = users(:one).plan_aprobado
    expect(plan.reglas?).to be_truthy
    expect(plan.dias.size).to eq(6)
    expect(response.body).to include("Incluido con tu membresía")
    assert_select "input[name=?]", "ejercicio[nombre]"             # editor inline
    expect(response.body).to include("seguimiento#marcar")          # check por ejercicio
    expect(response.body).to include("seguimiento#novedad")         # novedad del día
  end

  it "volver a abrir Mi plan no duplica el plan sugerido" do
    ObjetivoNutricional.fijar_para(users(:one), tipo: "deficit", peso_kg: 70)
    sign_in_as users(:one)

    get mi_plan_path
    expect {
      get mi_plan_path
    }.not_to change(PlanPersonalizado, :count)
  end

  # El punto de notificación de borradores aparece para el staff (Fase 5.11)
  it "el staff ve el punto de borradores cuando hay pendientes" do
    PlanPersonalizado.create!(user: users(:one), generado_por: "ia",
                              estado: "generando", rutina: {}, plan_nutricional: {})
    sign_in_as users(:entrenador)

    get root_path
    assert_select "#punto_borradores span.bg-error"
  end

  it "sin pendientes el punto no se muestra" do
    sign_in_as users(:entrenador)
    get root_path
    assert_select "#punto_borradores span.bg-error", count: 0
  end

  # Fase 14.2: tarjeta de ejercicio con miniatura del catálogo, línea densa y
  # "la vez pasada" calculada por el controller en UNA query (sin N+1).
  describe "tarjeta de ejercicio (Fase 14.2)" do
    let(:pecho) do
      Ejercicio.create!(dataset_id: "f14-0001", nombre: "Press banca", nombre_en: "Bench press",
                        nombre_normalizado: "press banca", categoria: "fuerza", musculo: "pecho")
    end
    let(:espalda) do
      Ejercicio.create!(dataset_id: "f14-0002", nombre: "Remo con barra", nombre_en: "Barbell row",
                        nombre_normalizado: "remo con barra", categoria: "fuerza", musculo: "espalda")
    end

    def crear_plan!(user)
      PlanPersonalizado.create!(
        user: user, generado_por: "reglas", estado: "aprobado", plan_nutricional: {},
        rutina: { "dias" => [
          { "dia" => "lunes", "enfoque" => "Empuje", "ejercicios" => [
            { "nombre" => pecho.nombre, "series" => 3, "repeticiones" => "12-15",
              "descanso_seg" => 90, "peso_sugerido_kg" => 60, "ejercicio_id" => pecho.id },
            { "nombre" => espalda.nombre, "series" => 4, "repeticiones" => "10", "ejercicio_id" => espalda.id },
            { "nombre" => "Fondos en paralelas", "series" => 3, "repeticiones" => "8" }
          ] }
        ] }
      )
    end

    it "renderiza miniaturas y el dato Anterior con una sola query de detalles" do
      crear_plan!(users(:one))
      registro = users(:one).registros_entrenamiento.create!(fecha: Date.current - 7)
      registro.detalles.create!(ejercicio: pecho, serie: 1, repeticiones: 8, peso_kg: 55)
      registro.detalles.create!(ejercicio: pecho, serie: 2, repeticiones: 10, peso_kg: 60)
      registro.detalles.create!(ejercicio: espalda, serie: 1, repeticiones: 12, peso_kg: 40)
      sign_in_as users(:one)

      consultas = []
      contador = ->(_nombre, _inicio, _fin, _id, payload) {
        sql = payload[:sql].to_s
        # name "SCHEMA" = queries de catálogo de Postgres que también mencionan la tabla
        consultas << sql if payload[:name] != "SCHEMA" && sql.start_with?("SELECT") && sql.include?("detalle_entrenamientos")
      }
      ActiveSupport::Notifications.subscribed(contador, "sql.active_record") { get mi_plan_path }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(media_ejercicio_path(pecho, tipo: :imagen))
      expect(response.body).to include(media_ejercicio_path(espalda, tipo: :imagen))
      # La última serie de la sesión más reciente, por ejercicio
      expect(response.body).to include("Anterior: 60 kg × 10")
      expect(response.body).to include("Anterior: 40 kg × 12")
      expect(consultas.size).to eq(1)
    end

    it "sin ejercicio_id conserva el número como fallback y no muestra Anterior" do
      crear_plan!(users(:one))
      sign_in_as users(:one)

      get mi_plan_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Anterior:")
      # Solo los dos ejercicios del catálogo llevan miniatura
      assert_select "img[src*=?]", "media/imagen", count: 2
      # El tercero (sin catálogo) mantiene su número
      assert_select "div[data-indice='2'] span.font-display", text: /\A\s*3\s*\z/
    end
  end
end
