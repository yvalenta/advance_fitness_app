require "rails_helper"

RSpec.describe PlanPersonalizadoPolicy, type: :model do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:entrenador) { users(:entrenador) }
  let(:admin) { users(:admin) }
  let(:plan_aprobado) do
    PlanPersonalizado.create!(user: dueno, generado_por: "reglas", estado: "aprobado",
                              rutina: { "dias" => [] }, plan_nutricional: {})
  end
  let(:plan_borrador) do
    PlanPersonalizado.create!(user: dueno, generado_por: "ia", estado: "borrador",
                              rutina: { "dias" => [] }, plan_nutricional: { "comidas" => [] })
  end

  it "show?: staff siempre; dueño solo si aprobado" do
    expect(PlanPersonalizadoPolicy.new(dueno, plan_aprobado).show?).to be true
    expect(PlanPersonalizadoPolicy.new(dueno, plan_borrador).show?).to be false
    expect(PlanPersonalizadoPolicy.new(otro, plan_aprobado).show?).to be false
    expect(PlanPersonalizadoPolicy.new(entrenador, plan_borrador).show?).to be true
  end

  it "revisar?/aprobar?/publicar?: entrenador o admin" do
    policy_ent = PlanPersonalizadoPolicy.new(entrenador, plan_borrador)
    expect(policy_ent.revisar?).to be true
    expect(policy_ent.aprobar?).to be true
    expect(policy_ent.publicar?).to be true
    expect(PlanPersonalizadoPolicy.new(dueno, plan_borrador).publicar?).to be false
  end

  it "editar?/editar_rutina?: staff o dueño del plan aprobado" do
    expect(PlanPersonalizadoPolicy.new(dueno, plan_aprobado).editar?).to be true
    expect(PlanPersonalizadoPolicy.new(dueno, plan_borrador).editar?).to be false
    expect(PlanPersonalizadoPolicy.new(otro, plan_aprobado).editar?).to be false
    expect(PlanPersonalizadoPolicy.new(admin, plan_borrador).editar?).to be true
    expect(PlanPersonalizadoPolicy.new(dueno, plan_aprobado).editar_rutina?).to be true
  end

  it "editar_json?: solo staff (peligroso)" do
    expect(PlanPersonalizadoPolicy.new(dueno, plan_aprobado).editar_json?).to be false
    expect(PlanPersonalizadoPolicy.new(entrenador, plan_aprobado).editar_json?).to be true
  end
end
