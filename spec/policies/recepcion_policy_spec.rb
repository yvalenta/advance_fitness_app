require "rails_helper"

# BLINDAJE del rol `recepcion` (Fase 18k). El mostrador cobra, da acceso, arma
# membresías y da de alta miembros — y nada más. Este archivo es la línea que
# no debe cruzarse: si alguien "simplifica" metiendo `recepcion` dentro de
# `staff?`, o agrega `user.mostrador?` a una policy de entrenamiento, estos
# ejemplos fallan a propósito.
#
# Lo que recepción SÍ puede vive en los specs de cada policy (pago, acceso,
# membresia, user); acá se prueba el reverso.
RSpec.describe "Rol recepción (mostrador)", type: :model do
  let(:recepcion) { users(:recepcion) }
  let(:admin) { users(:admin) }
  let(:entrenador) { users(:entrenador) }
  let(:miembro) { users(:one) }
  let(:tenant) { tenants(:advance_fitness) }

  describe "los dos permisos del User" do
    it "recepción es mostrador pero NO staff" do
      expect(recepcion.mostrador?).to be true
      expect(recepcion.staff?).to be false
      expect(recepcion.recepcion?).to be true
    end

    it "el entrenador es staff pero NO mostrador" do
      expect(entrenador.staff?).to be true
      expect(entrenador.mostrador?).to be false
    end

    it "el admin hace los dos oficios" do
      expect(admin.staff?).to be true
      expect(admin.mostrador?).to be true
    end

    it "recepción es un rol de tenant, no del portal comercial" do
      expect(recepcion.global?).to be false
      expect(User::ROLES).to include("recepcion")
      expect(User::ROLES_GLOBALES).not_to include("recepcion")
    end

    it "sin tenant no valida (como cualquier rol de gimnasio)" do
      sin_tenant = User.new(email_address: "recepcion-sin-tenant@x.com",
                            password: "clave1234", rol: "recepcion", nombre: "R")
      expect(sin_tenant).not_to be_valid
      expect(sin_tenant.errors[:tenant]).to be_present
    end
  end

  describe "el admin puede asignar el rol" do
    it "recepcion está en ROLES_ASIGNABLES" do
      expect(Admin::UsersController::ROLES_ASIGNABLES).to include("recepcion")
    end

    it "y los roles globales siguen fuera (viven en el portal comercial)" do
      expect(Admin::UsersController::ROLES_ASIGNABLES)
        .not_to include("superadmin", "comercializador")
    end
  end

  describe "entrenamiento: recepción no lee ni escribe nada" do
    let(:medicion) { Medicion.create!(user: miembro, fecha: Date.current, peso_kg: 70) }
    let(:plan) do
      PlanPersonalizado.create!(user: miembro, generado_por: "reglas", estado: "aprobado",
                                rutina: { "dias" => [] }, plan_nutricional: {})
    end

    it "mediciones: ni lista, ni crea, ni edita, y su scope no incluye las ajenas" do
      politica = MedicionPolicy.new(recepcion, medicion)
      expect(politica.index?).to be false
      expect(politica.new?).to be false
      expect(politica.edit?).to be false
      expect(politica.update?).to be false
      expect(politica.create?).to be false
      expect(MedicionPolicy::Scope.new(recepcion, Medicion).resolve).not_to include(medicion)
    end

    it "planes personalizados: ni ve, ni edita, ni publica, ni toca el JSON" do
      politica = PlanPersonalizadoPolicy.new(recepcion, plan)
      expect(politica.show?).to be false
      expect(politica.revisar?).to be false
      expect(politica.aprobar?).to be false
      expect(politica.publicar?).to be false
      expect(politica.editar?).to be false
      expect(politica.editar_rutina?).to be false
      expect(politica.editar_json?).to be false
      expect(PlanPersonalizadoPolicy::Scope.new(recepcion, PlanPersonalizado).resolve)
        .not_to include(plan)
    end

    it "series y Analista de Performance: no dispara el análisis" do
      expect(DetalleEntrenamientoPolicy.new(recepcion, DetalleEntrenamiento).analizar?).to be false
    end

    it "plantillas de comida y de ejercicio: herramienta de staff" do
      expect(PlantillaComidaPolicy.new(recepcion, PlantillaComida).create?).to be false
      expect(PlantillaComidaPolicy.new(recepcion, PlantillaComida).destroy?).to be false
      expect(PlantillaEjercicioPolicy.new(recepcion, PlantillaEjercicio).create?).to be false
      expect(PlantillaEjercicioPolicy.new(recepcion, PlantillaEjercicio).destroy?).to be false
    end

    it "puntos: el ajuste manual del ledger es de staff" do
      expect(RegistroPuntoPolicy.new(recepcion, RegistroPunto).create?).to be false
    end
  end

  describe "ciclo menstrual: sigue siendo SOLO de la propia usuaria" do
    let(:ciclo) do
      miembro.consentimientos.create!(tipo: "ciclo_menstrual", accion: "otorgado",
                                      version_texto: "ciclo-v1")
      CicloMenstrual.create!(user: miembro, creado_por: miembro, fecha_inicio: Date.current)
    end

    it "ni lo ve, ni lo crea, ni lo borra" do
      politica = CicloMenstrualPolicy.new(recepcion, ciclo)
      expect(politica.show?).to be false
      expect(politica.create?).to be false
      expect(politica.destroy?).to be false
    end

    it "su scope es VACÍO aunque existan ciclos en su tenant" do
      ciclo
      expect(CicloMenstrualPolicy::Scope.new(recepcion, CicloMenstrual).resolve).to be_empty
    end
  end

  describe "administración: recepción no manda" do
    it "no enciende ni apaga funcionalidades del tenant" do
      expect(TenantPolicy.new(recepcion, tenant).funcionalidades?).to be false
      expect(TenantPolicy.new(admin, tenant).funcionalidades?).to be true
    end

    it "no gestiona tenants" do
      expect(TenantPolicy.new(recepcion, tenant).index?).to be false
      expect(TenantPolicy.new(recepcion, tenant).update?).to be false
    end

    it "no gestiona suscripciones al plan personalizado (sigue siendo del admin)" do
      expect(SuscripcionPolicy.new(recepcion, Suscripcion).index?).to be false
      expect(SuscripcionPolicy.new(recepcion, Suscripcion).create?).to be false
      expect(SuscripcionPolicy.new(recepcion, Suscripcion).update?).to be false
    end

    it "no publica contenido: blog ni novedades" do
      post = Post.create!(autor: admin, tenant_id: tenant.id, titulo: "Post",
                          publicado: false)
      novedad = Novedad.create!(tenant_id: tenant.id, titulo: "N", contenido: "x")

      expect(PostPolicy.new(recepcion, post).admin_index?).to be false
      expect(PostPolicy.new(recepcion, post).create?).to be false
      expect(PostPolicy.new(recepcion, post).publicar?).to be false
      # Un borrador tampoco se le muestra (`show?` = publicado? || staff?)
      expect(PostPolicy.new(recepcion, post).show?).to be false

      expect(NovedadPolicy.new(recepcion, novedad).admin_index?).to be false
      expect(NovedadPolicy.new(recepcion, novedad).create?).to be false
      expect(NovedadPolicy.new(recepcion, novedad).destroy?).to be false
    end
  end
end
