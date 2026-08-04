require "rails_helper"

RSpec.describe HistorialEntrenamiento, type: :model do
  before do
    @user = users(:one)
    @ejercicio = Ejercicio.create!(dataset_id: "0025", nombre: "Press de banca",
                                   nombre_en: "barbell bench press", musculo: "pecho", categoria: "chest")
  end

  # Un día de entrenamiento: `series` series de 10 reps × `peso_kg`.
  def entrenar(fecha, series: 1, peso_kg: 50)
    registro = RegistroEntrenamiento.create!(user: @user, fecha: fecha, ejercicios: {})
    series.times do |i|
      registro.detalles.create!(ejercicio: @ejercicio, serie: i + 1, repeticiones: 10, peso_kg: peso_kg)
    end
  end

  def plan_v2_aprobado(hace: 1.week)
    plan = PlanPersonalizado.new(
      user: @user, generado_por: "reglas", estado: "aprobado", plan_nutricional: {},
      rutina: { "dias" => [ { "dia" => "lunes", "ejercicios" => [] } ],
                "semanas" => [ { "numero" => 1, "etiqueta" => "Adaptación", "descarga" => false },
                               { "numero" => 2, "etiqueta" => "Acumulación", "descarga" => false },
                               { "numero" => 3, "etiqueta" => "Intensificación", "descarga" => false },
                               { "numero" => 4, "etiqueta" => "Descarga", "descarga" => true } ] })
    plan.created_at = hace.ago
    plan.save!
    plan
  end

  it "resumen_semanal agrupa por semana calendario — contrato §18.7 intacto" do
    lunes = Date.current.beginning_of_week
    entrenar(lunes, series: 2)          # 2 × 10 reps × 50 kg = 1000
    entrenar(lunes - 1.week, series: 1) # 500

    resumen = HistorialEntrenamiento.resumen_semanal(@user)

    expect(resumen).to eq([
      { semana: (lunes - 1.week).iso8601, series: 1, volumen_kg: 500.0 },
      { semana: lunes.iso8601, series: 2, volumen_kg: 1000.0 }
    ])
  end

  it "resumen_semanal sin datos devuelve lista vacía" do
    expect(HistorialEntrenamiento.resumen_semanal(@user)).to eq([])
  end

  # ── Etapa 14.10 ──────────────────────────────────────────────────────────
  it "resumen_mesociclo agrupa por semana del plan v2 y excluye lo fuera del ciclo" do
    plan_v2_aprobado # ciclo desde el lunes de la semana pasada → hoy = semana 2
    inicio = Date.current.beginning_of_week - 1.week
    entrenar(inicio - 2.days)            # previo al ciclo → excluido
    entrenar(inicio, series: 2)          # semana 1
    entrenar(Date.current, series: 1)    # semana 2

    resumen = HistorialEntrenamiento.resumen_mesociclo(@user)

    expect(resumen).to eq([
      { semana: 1, etiqueta: "Adaptación", descarga: false, series: 2, volumen_kg: 1000.0 },
      { semana: 2, etiqueta: "Acumulación", descarga: false, series: 1, volumen_kg: 500.0 }
    ])
  end

  it "sin plan v2 vigente cae a la agrupación calendario" do
    entrenar(Date.current)

    resumen = HistorialEntrenamiento.resumen_mesociclo(@user)

    expect(resumen).to eq([ { semana: Date.current.beginning_of_week.iso8601,
                              series: 1, volumen_kg: 500.0 } ])
  end

  it "un plan v1 (una semana identidad) también cae a la agrupación calendario" do
    plan = PlanPersonalizado.create!(user: @user, generado_por: "reglas", estado: "aprobado",
                                     rutina: { "dias" => [ { "dia" => "lunes", "ejercicios" => [] } ] },
                                     plan_nutricional: {})
    entrenar(Date.current)

    resumen = HistorialEntrenamiento.resumen_mesociclo(@user)

    expect(plan.reload.aprobado?).to be_truthy
    expect(resumen.first[:semana]).to eq(Date.current.beginning_of_week.iso8601)
  end
end
