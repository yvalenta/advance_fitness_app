require "rails_helper"

RSpec.describe Rutina::Calendario do
  include ActiveSupport::Testing::TimeHelpers

  def nutricion
    { "kcal_diarias" => 500, "comidas" => [ { "nombre" => "Almuerzo", "kcal" => 500 } ] }
  end

  def rutina_v2(inicio: "2026-08-03")
    { "version" => 2,
      "mesociclo" => { "nombre" => "Base", "semanas_total" => 4, "inicio" => inicio, "progresion" => "lineal" },
      "dias" => [
        { "dia" => "lunes", "ejercicios" => [] },
        { "dia" => "jueves", "ejercicios" => [] },
        { "dia" => "cardio", "ejercicios" => [] } # nombre fuera de DIAS_OFFSET
      ],
      "semanas" => [ { "numero" => 1, "etiqueta" => "Semana 1", "descarga" => false,
                      "ajuste" => { "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 },
                      "dias" => nil } ] }
  end

  def plan_v2
    PlanPersonalizado.create!(user: users(:one), rutina: rutina_v2, plan_nutricional: nutricion)
  end

  describe ".fecha_de" do
    it "ubica cada día por su offset desde el lunes de inicio, semana a semana" do
      plan = plan_v2
      # inicio 2026-08-03 es lunes
      expect(described_class.fecha_de(plan, semana: 1, dia_indice: 0)).to eq(Date.new(2026, 8, 3))
      expect(described_class.fecha_de(plan, semana: 1, dia_indice: 1)).to eq(Date.new(2026, 8, 6))  # jueves
      expect(described_class.fecha_de(plan, semana: 2, dia_indice: 1)).to eq(Date.new(2026, 8, 13)) # jueves +7
    end

    it "un día con nombre desconocido usa su posición como offset" do
      expect(described_class.fecha_de(plan_v2, semana: 1, dia_indice: 2)).to eq(Date.new(2026, 8, 5))
    end
  end

  describe ".semana_de" do
    it "devuelve la semana 1-based, sin clamp en los extremos" do
      plan = plan_v2
      expect(described_class.semana_de(plan, Date.new(2026, 8, 3))).to eq(1)  # lunes de inicio
      expect(described_class.semana_de(plan, Date.new(2026, 8, 9))).to eq(1)  # domingo de la semana 1
      expect(described_class.semana_de(plan, Date.new(2026, 8, 10))).to eq(2)
      expect(described_class.semana_de(plan, Date.new(2026, 8, 2))).to eq(0)  # antes del inicio
      expect(described_class.semana_de(plan, Date.new(2026, 9, 7))).to eq(6)  # mesociclo (4) ya terminado
    end
  end

  describe ".inicio_de" do
    it "para un plan v1 el inicio es el lunes de la semana de creación" do
      plan = travel_to(Date.new(2026, 8, 5)) do # miércoles
        PlanPersonalizado.create!(user: users(:one),
                                  rutina: { "dias" => [ { "dia" => "lunes", "ejercicios" => [] } ] },
                                  plan_nutricional: nutricion)
      end

      expect(described_class.inicio_de(plan)).to eq(Date.new(2026, 8, 3))
      expect(described_class.fecha_de(plan, semana: 1, dia_indice: 0)).to eq(Date.new(2026, 8, 3))
      expect(described_class.semana_de(plan, Date.new(2026, 8, 12))).to eq(2)
    end

    it "para un contrato v2 manda mesociclo['inicio']" do
      expect(described_class.inicio_de(plan_v2)).to eq(Date.new(2026, 8, 3))
    end
  end
end
