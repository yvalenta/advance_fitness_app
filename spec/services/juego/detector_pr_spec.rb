require "rails_helper"

RSpec.describe Juego::DetectorPr do
  let(:user) { users(:one) }
  let(:ejercicio) do
    Ejercicio.create!(dataset_id: "test-pr-0001", nombre: "Press banca", nombre_en: "Bench press",
                      nombre_normalizado: "press banca", categoria: "fuerza", musculo: "pecho")
  end
  let(:registro) { user.registros_entrenamiento.create!(fecha: Date.current) }

  def serie!(reps:, peso: nil, en: registro)
    numero = en.detalles.where(ejercicio: ejercicio).maximum(:serie).to_i + 1
    en.detalles.create!(ejercicio: ejercicio, serie: numero, repeticiones: reps, peso_kg: peso)
  end

  # Deja una vara previa (baseline de ayer) contra la cual competir hoy.
  def baseline!(reps:, peso: nil)
    ayer = user.registros_entrenamiento.create!(fecha: Date.yesterday)
    described_class.evaluar!(serie!(reps: reps, peso: peso, en: ayer))
  end

  it "el primer registro NO es PR: crea la vara baseline sin puntos ni celebración" do
    prs = described_class.evaluar!(serie!(reps: 8, peso: 60))

    expect(prs).to eq []
    expect(user.records_personales.pluck(:tipo, :baseline))
      .to contain_exactly([ "peso_max", true ], [ "volumen_max", true ])
    expect(user.registros_puntos.where(tipo: "pr")).to be_empty
  end

  it "superar la vara crea el PR, conserva el anterior como historial y otorga puntos" do
    baseline!(reps: 8, peso: 60) # peso 60, volumen 480

    prs = described_class.evaluar!(serie!(reps: 8, peso: 70)) # 70 > 60 y 560 > 480

    expect(prs.map(&:tipo)).to contain_exactly("peso_max", "volumen_max")
    expect(prs).to all(have_attributes(baseline: false, superado_en: nil))
    # el superado queda marcado, jamás borrado (patrón pagos.anulado_en)
    expect(user.records_personales.where.not(superado_en: nil).pluck(:tipo))
      .to contain_exactly("peso_max", "volumen_max")
    expect(user.records_personales.count).to eq 4
    expect(user.registros_puntos.where(tipo: "pr").sum(:puntos)).to eq 60 # 30 por cada PR
  end

  it "solo bate el tipo que de verdad supera (peso sube, volumen no)" do
    baseline!(reps: 8, peso: 60) # volumen 480

    prs = described_class.evaluar!(serie!(reps: 2, peso: 65)) # peso 65 > 60; volumen 130 < 480

    expect(prs.map(&:tipo)).to eq [ "peso_max" ]
    expect(user.records_personales.vigentes.find_by(tipo: "volumen_max").valor).to eq 480
  end

  it "una serie menor no toca nada" do
    baseline!(reps: 8, peso: 60)

    expect {
      expect(described_class.evaluar!(serie!(reps: 6, peso: 50))).to eq []
    }.not_to change { [ user.records_personales.count, user.registros_puntos.count ] }
  end

  it "el empate NO es PR: igualar la marca no la supera" do
    baseline!(reps: 8, peso: 60)

    expect(described_class.evaluar!(serie!(reps: 8, peso: 60))).to eq []
    expect(user.registros_puntos.where(tipo: "pr")).to be_empty
  end

  it "reps_max compite solo a peso corporal; las series con peso no lo tocan" do
    baseline!(reps: 10) # peso corporal → baseline de reps_max

    prs = described_class.evaluar!(serie!(reps: 12)) # 12 > 10 a peso corporal
    expect(prs.map(&:tipo)).to eq [ "reps_max" ]

    # 20 reps lastradas NO baten las 12 libres: compiten en peso/volumen
    prs_lastradas = described_class.evaluar!(serie!(reps: 20, peso: 20))
    expect(prs_lastradas).to eq [] # primer registro con peso → baselines
    expect(user.records_personales.vigentes.find_by(tipo: "reps_max").valor).to eq 12
  end

  it "es idempotente: re-evaluar el mismo detalle no duplica PRs ni puntos" do
    baseline!(reps: 8, peso: 60)
    detalle = serie!(reps: 8, peso: 70)
    described_class.evaluar!(detalle)

    expect {
      expect(described_class.evaluar!(detalle)).to eq []
    }.not_to change { [ user.records_personales.count, user.registros_puntos.sum(:puntos) ] }
  end

  it "las series de registrar_cumplido! también compiten: es peso real levantado" do
    baseline!(reps: 8, peso: 60)

    detalles = DetalleEntrenamiento.registrar_cumplido!(registro: registro, ejercicio: ejercicio,
                                                        series: 3, repeticiones: "8-10", peso_kg: 70)
    prs = described_class.evaluar!(detalles.first)

    expect(prs.map(&:tipo)).to contain_exactly("peso_max", "volumen_max")
  end
end
