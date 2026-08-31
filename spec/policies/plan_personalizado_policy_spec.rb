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

  # Defensa en profundidad (tarea 2026-08-31, patrón de MedicionPolicy): el
  # rol ya no basta — el DUEÑO del plan debe tener puesto en el gimnasio del
  # staff. Este es el check que frena a un controller descuidado con un find
  # crudo, aunque el editor ya cargue por policy_scope.
  it "el staff de A no toca el plan de un miembro de B, aunque sea staff" do
    miembro_mp = User.create!(email_address: "miembro-mp-plan@x.com", password: "clave1234",
                              rol: "miembro", tenant: tenants(:megaplex), nombre: "Miembro MP")
    plan_mp = PlanPersonalizado.create!(user: miembro_mp, generado_por: "ia", estado: "borrador",
                                        rutina: { "dias" => [] }, plan_nutricional: { "comidas" => [] })

    [ entrenador, admin ].each do |staff|
      policy = PlanPersonalizadoPolicy.new(staff, plan_mp)
      expect(policy.show?).to be false
      expect(policy.revisar?).to be false
      expect(policy.publicar?).to be false
      expect(policy.editar?).to be false
      expect(policy.editar_rutina?).to be false
      expect(policy.editar_json?).to be false
    end

    # …el dueño de B conserva sus derechos sobre su propio plan aprobado…
    plan_aprobado_mp = PlanPersonalizado.create!(user: miembro_mp, generado_por: "reglas",
                                                 estado: "aprobado", rutina: { "dias" => [] },
                                                 plan_nutricional: {})
    expect(PlanPersonalizadoPolicy.new(miembro_mp, plan_aprobado_mp).show?).to be true
    expect(PlanPersonalizadoPolicy.new(miembro_mp, plan_aprobado_mp).editar?).to be true

    # …y con la CLASE (la cola de borradores) sigue decidiendo solo el rol.
    expect(PlanPersonalizadoPolicy.new(entrenador, PlanPersonalizado).revisar?).to be true
  end
end
