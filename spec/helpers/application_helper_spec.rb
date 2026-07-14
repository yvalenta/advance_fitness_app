require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  # Fase 5.14: evita repetir el valor crudo de generado_por (y la palabra "IA")
  # en las vistas de staff.
  it "origen_plan traduce los tres generadores conocidos" do
    expect(helper.origen_plan(PlanPersonalizado.new(generado_por: "ia"))).to eq("análisis automático")
    expect(helper.origen_plan(PlanPersonalizado.new(generado_por: "reglas"))).to eq("plan de membresía")
    expect(helper.origen_plan(PlanPersonalizado.new(generado_por: "entrenador"))).to eq("entrenador")
  end
end
