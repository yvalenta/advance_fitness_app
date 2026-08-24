require "rails_helper"

RSpec.describe ReprogramacionDiaPolicy do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:plan) { PlanPersonalizado.create!(user: dueno, generado_por: "reglas", estado: "aprobado", rutina: { "dias" => [] }, plan_nutricional: {}) }
  let(:record) { ReprogramacionDia.new(plan_personalizado: plan, fecha_original: Date.current, fecha_destino: Date.current + 1) }

  it "el dueño del plan puede crear y borrar su reprogramación" do
    expect(described_class.new(dueno, record)).to be_create
    expect(described_class.new(dueno, record)).to be_destroy
  end

  it "otro miembro no puede tocar la reprogramación de un plan ajeno" do
    expect(described_class.new(otro, record)).not_to be_create
    expect(described_class.new(otro, record)).not_to be_destroy
  end

  it "el staff tampoco (self-service, mismo criterio que ciclo menstrual)" do
    expect(described_class.new(users(:entrenador), record)).not_to be_create
  end
end
