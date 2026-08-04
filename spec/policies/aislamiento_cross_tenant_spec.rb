require "rails_helper"

# El test más crítico de multi-tenancy (SDD §16.6, Nota 14 y Etapa 1 del plan
# de estabilización): garantiza que el `Scope` de cada policy jamás incluye
# registros de otro tenant, incluso cuando el usuario es staff. Es la RED de
# seguridad de la doble capa — la lógica vive en las policies; este spec
# atrapa el bug cuando la lógica falla.
#
# Modelos catálogo global (SDD §16.6) deliberadamente excluidos: Plan,
# Ejercicio, PlantillaComida, PlantillaEjercicio.
RSpec.describe "Aislamiento cross-tenant en policies", type: :model do
  let(:tenant_af) { tenants(:advance_fitness) }
  let(:tenant_mp) { tenants(:megaplex) }

  let(:admin_af) { users(:admin) }
  let(:miembro_af) { users(:one) }

  let(:admin_mp) do
    User.create!(email_address: "admin-mp@x.com", password: "clave1234",
                 rol: "admin", tenant: tenant_mp, nombre: "Admin MP")
  end
  let(:miembro_mp) do
    User.create!(email_address: "miembro-mp@x.com", password: "clave1234",
                 rol: "miembro", tenant: tenant_mp, nombre: "Miembro MP",
                 fecha_nacimiento: "1990-01-01", sexo: "M",
                 talla_cm: 175, nivel_actividad: 1.55)
  end

  # Helper: reduce el boilerplate "el staff del tenant A NO ve el registro del
  # tenant B, y viceversa". `policy_class` es la clase de policy; `record_af` y
  # `record_mp` los registros ya creados en cada tenant.
  def expect_aislado(policy_class, record_af:, record_mp:)
    scope_af = policy_class::Scope.new(admin_af, record_af.class).resolve
    scope_mp = policy_class::Scope.new(admin_mp, record_mp.class).resolve

    expect(scope_af).to include(record_af)
    expect(scope_af).not_to include(record_mp)
    expect(scope_mp).to include(record_mp)
    expect(scope_mp).not_to include(record_af)
  end

  it "UserPolicy — staff solo ve users de su tenant" do
    admin_mp; miembro_mp
    expect_aislado(UserPolicy, record_af: admin_af, record_mp: admin_mp)
  end

  it "MembresiaPolicy — vía user" do
    membresia_af = membresias(:activa_one)
    membresia_mp = Membresia.create!(user: miembro_mp, estado: "activa",
                                     fecha_inicio: Date.current,
                                     fecha_vencimiento: Date.current + 30)
    expect_aislado(MembresiaPolicy, record_af: membresia_af, record_mp: membresia_mp)
  end

  it "AccesoPolicy — vía user" do
    acceso_af = Acceso.create!(user: miembro_af, fecha_hora: Time.current)
    acceso_mp = Acceso.create!(user: miembro_mp, fecha_hora: Time.current)
    expect_aislado(AccesoPolicy, record_af: acceso_af, record_mp: acceso_mp)
  end

  it "PagoPolicy — vía membresía → user" do
    pago_af = pagos(:inicial_one)
    membresia_mp = Membresia.create!(user: miembro_mp, estado: "activa",
                                     fecha_inicio: Date.current,
                                     fecha_vencimiento: Date.current + 30)
    pago_mp = membresia_mp.pagos.create!(monto: 80_000, metodo: "efectivo",
                                         registrado_por: admin_mp, fecha_pago: Date.current,
                                         periodo_inicio: Date.current, periodo_fin: Date.current + 30)
    expect_aislado(PagoPolicy, record_af: pago_af, record_mp: pago_mp)
  end

  it "SuscripcionPolicy — vía user" do
    plan = planes(:free)
    susc_af = Suscripcion.create!(user: miembro_af, plan: plan, estado: "activa",
                                  fecha_inicio: Date.current)
    susc_mp = Suscripcion.create!(user: miembro_mp, plan: plan, estado: "activa",
                                  fecha_inicio: Date.current)
    expect_aislado(SuscripcionPolicy, record_af: susc_af, record_mp: susc_mp)
  end

  it "MedicionPolicy — vía user" do
    med_af = Medicion.create!(user: miembro_af, fecha: Date.current, peso_kg: 70)
    med_mp = Medicion.create!(user: miembro_mp, fecha: Date.current, peso_kg: 72)
    expect_aislado(MedicionPolicy, record_af: med_af, record_mp: med_mp)
  end

  it "ObjetivoNutricionalPolicy — vía user" do
    obj_af = ObjetivoNutricional.create!(user: miembro_af, tipo: "mantenimiento",
                                         peso_kg: 70, tdee_kcal: 2200, objetivo_kcal: 2200)
    obj_mp = ObjetivoNutricional.create!(user: miembro_mp, tipo: "mantenimiento",
                                         peso_kg: 72, tdee_kcal: 2400, objetivo_kcal: 2400)
    expect_aislado(ObjetivoNutricionalPolicy, record_af: obj_af, record_mp: obj_mp)
  end

  it "RegistroCaloriaPolicy — vía user" do
    reg_af = RegistroCaloria.create!(user: miembro_af, fecha: Date.current, kcal_consumidas: 1800)
    reg_mp = RegistroCaloria.create!(user: miembro_mp, fecha: Date.current, kcal_consumidas: 1900)
    expect_aislado(RegistroCaloriaPolicy, record_af: reg_af, record_mp: reg_mp)
  end

  it "RegistroEntrenamientoPolicy — vía user" do
    reg_af = RegistroEntrenamiento.create!(user: miembro_af, fecha: Date.current)
    reg_mp = RegistroEntrenamiento.create!(user: miembro_mp, fecha: Date.current)
    expect_aislado(RegistroEntrenamientoPolicy, record_af: reg_af, record_mp: reg_mp)
  end

  it "PlanPersonalizadoPolicy — vía user" do
    plan_af = PlanPersonalizado.create!(user: miembro_af, generado_por: "reglas",
                                        estado: "aprobado", rutina: { "dias" => [] },
                                        plan_nutricional: {})
    plan_mp = PlanPersonalizado.create!(user: miembro_mp, generado_por: "reglas",
                                        estado: "aprobado", rutina: { "dias" => [] },
                                        plan_nutricional: {})
    expect_aislado(PlanPersonalizadoPolicy, record_af: plan_af, record_mp: plan_mp)
  end

  it "PostPolicy — vía tenant_id directo" do
    post_af = Post.create!(autor: admin_af, tenant_id: tenant_af.id,
                           titulo: "Post AF", publicado: true, publicado_en: Time.current)
    post_mp = Post.create!(autor: admin_mp, tenant_id: tenant_mp.id,
                           titulo: "Post MP", publicado: true, publicado_en: Time.current)
    expect_aislado(PostPolicy, record_af: post_af, record_mp: post_mp)
  end

  it "NovedadPolicy — vía tenant_id directo" do
    nov_af = Novedad.create!(tenant_id: tenant_af.id, titulo: "N AF", contenido: "x")
    nov_mp = Novedad.create!(tenant_id: tenant_mp.id, titulo: "N MP", contenido: "x")
    expect_aislado(NovedadPolicy, record_af: nov_af, record_mp: nov_mp)
  end

  it "DetalleEntrenamientoPolicy — vía registro → user" do
    reg_af = RegistroEntrenamiento.create!(user: miembro_af, fecha: Date.current)
    reg_mp = RegistroEntrenamiento.create!(user: miembro_mp, fecha: Date.current)
    # Se crea un ejercicio efímero del catálogo global
    ejercicio = Ejercicio.first || Ejercicio.create!(nombre: "Sentadilla", nombre_en: "Squat",
                                                     nombre_normalizado: "sentadilla",
                                                     musculo: "pierna", categoria: "fuerza",
                                                     dataset_id: "seed-sentadilla")
    det_af = DetalleEntrenamiento.create!(registro_entrenamiento: reg_af, ejercicio: ejercicio,
                                          serie: 1, repeticiones: 10, peso_kg: 50, rpe: 7)
    det_mp = DetalleEntrenamiento.create!(registro_entrenamiento: reg_mp, ejercicio: ejercicio,
                                          serie: 1, repeticiones: 10, peso_kg: 55, rpe: 7)
    expect_aislado(DetalleEntrenamientoPolicy, record_af: det_af, record_mp: det_mp)
  end

  it "CicloMenstrualPolicy — MÁS cerrado que el aislamiento por tenant: el admin del MISMO tenant obtiene scope VACÍO" do
    # Aquí no aplica `expect_aislado`: ese helper asume que el staff ve los
    # registros de su tenant, y este scope no tiene (ni debe tener) rama de
    # staff — el ciclo menstrual es un dato de salud sensible que se aísla
    # por PERSONA. Si alguien agrega `user.staff?` o `del_tenant` a
    # CicloMenstrualPolicy::Scope, este ejemplo falla a propósito.
    miembro_af.consentimientos.create!(tipo: "ciclo_menstrual", accion: "otorgado",
                                       version_texto: "ciclo-v1")
    ciclo = CicloMenstrual.create!(user: miembro_af, creado_por: miembro_af,
                                   fecha_inicio: Date.current)

    expect(CicloMenstrualPolicy::Scope.new(admin_af, CicloMenstrual).resolve).to be_empty
    expect(CicloMenstrualPolicy::Scope.new(miembro_af, CicloMenstrual).resolve)
      .to contain_exactly(ciclo)
  end

  it "ConsentimientoPolicy — estrictamente personal: cada quien ve SOLO los suyos" do
    # El scope es más cerrado que el resto (ni el staff ve los ajenos), así
    # que el aislamiento se prueba con consentimientos de los propios admins.
    cons_af = Consentimiento.create!(user: admin_af, tipo: "tabla_posiciones",
                                     accion: "otorgado", version_texto: "v1")
    cons_mp = Consentimiento.create!(user: admin_mp, tipo: "tabla_posiciones",
                                     accion: "otorgado", version_texto: "v1")
    expect_aislado(ConsentimientoPolicy, record_af: cons_af, record_mp: cons_mp)
  end
end
