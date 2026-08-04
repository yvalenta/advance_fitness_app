require "rails_helper"
require "rake"

RSpec.describe "mesociclo.rake", type: :model do
  include ActiveSupport::Testing::TimeHelpers

  before(:all) do
    unless Rake::Task.task_defined?("mesociclo:migrar")
      Rake::Task.define_task(:environment)
      load Rails.root.join("lib/tasks/mesociclo.rake")
    end
  end

  # Corre la tarea con ENV controlado, capturando el reporte y restaurando
  # el entorno pase lo que pase (incluido el abort de la guardia).
  def correr(tarea, env = {})
    previos = env.keys.index_with { |clave| ENV[clave] }
    env.each { |clave, valor| ENV[clave] = valor }
    original = $stdout
    salida = StringIO.new
    $stdout = salida
    Rake::Task[tarea].reenable
    Rake::Task[tarea].invoke
    salida.string
  ensure
    $stdout = original if original
    previos&.each { |clave, valor| valor.nil? ? ENV.delete(clave) : (ENV[clave] = valor) }
  end

  def nutricion
    { "kcal_diarias" => 500, "comidas" => [ { "nombre" => "Almuerzo", "kcal" => 500 } ] }
  end

  def dias_base
    [ { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [
      { "uid" => "u-press", "nombre" => "Press banca", "series" => 4, "repeticiones" => "8-10" }
    ] } ]
  end

  def plan_v1
    PlanPersonalizado.create!(user: users(:one), rutina: { "dias" => dias_base }, plan_nutricional: nutricion)
  end

  describe "mesociclo:migrar" do
    it "dry-run por defecto: reporta sin escribir" do
      plan = plan_v1
      salida = correr("mesociclo:migrar")

      expect(plan.reload.rutina).not_to have_key("version")
      expect(salida).to include("dry-run")
      expect(salida).to include("APLICAR=1")
    end

    it "con APLICAR=1 envuelve la rutina en el contrato v2 estándar, salta lo no migrable y es idempotente" do
      plan = plan_v1
      generando = PlanPersonalizado.create!(user: users(:one), generado_por: "ia",
                                            estado: "generando", rutina: {}, plan_nutricional: {})

      travel_to(Date.new(2026, 8, 5)) { correr("mesociclo:migrar", { "APLICAR" => "1" }) }

      rutina = plan.reload.rutina
      expect(rutina["version"]).to eq(2)
      expect(rutina.dig("mesociclo", "semanas_total")).to eq(4)
      expect(rutina.dig("mesociclo", "inicio")).to eq("2026-08-03") # lunes de esa semana
      expect(rutina.dig("mesociclo", "progresion")).to eq("lineal")
      expect(rutina["semanas"].size).to eq(4)
      expect(rutina["semanas"].all? { |sem| sem["dias"].nil? }).to be_truthy # todas heredan
      expect(rutina["semanas"].first["ajuste"]).to eq({ "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 })
      expect(rutina["dias"]).to eq(dias_base)   # los días existentes no se tocan
      expect(generando.reload.rutina).to eq({}) # sin rutina → saltado

      expect { correr("mesociclo:migrar", { "APLICAR" => "1" }) }
        .not_to change { plan.reload.rutina }
    end

    it "aborta en dev con DEV_DATABASE_URL activo sin CONFIRMO=1" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("development"))

      expect { correr("mesociclo:migrar", { "DEV_DATABASE_URL" => "postgres://supabase" }) }
        .to raise_error(SystemExit)
      expect {
        correr("mesociclo:migrar", { "DEV_DATABASE_URL" => "postgres://supabase", "CONFIRMO" => "1" })
      }.not_to raise_error
    end
  end

  describe "mesociclo:revertir" do
    it "es lossless cuando ninguna semana está materializada" do
      plan = plan_v1
      original = plan.rutina

      correr("mesociclo:migrar", { "APLICAR" => "1" })
      correr("mesociclo:revertir", { "APLICAR" => "1" })

      expect(plan.reload.rutina).to eq(original)
    end

    it "salta y avisa con semanas materializadas; FORZAR=1 las descarta" do
      plan = plan_v1
      correr("mesociclo:migrar", { "APLICAR" => "1" })
      plan.reload.actualizar_ajuste_semana!(2, { "series_delta" => 1 })
      plan.materializar_semana!(2)

      salida = correr("mesociclo:revertir", { "APLICAR" => "1" })
      expect(plan.reload.rutina["version"]).to eq(2) # intacto
      expect(salida).to include("materializada")

      correr("mesociclo:revertir", { "APLICAR" => "1", "FORZAR" => "1" })
      expect(plan.reload.rutina).not_to have_key("version")
      expect(plan.reload.rutina["dias"]).to eq(dias_base)
    end
  end
end
