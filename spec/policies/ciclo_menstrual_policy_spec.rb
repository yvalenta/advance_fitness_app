require "rails_helper"

# La única policy del repo donde el staff NO ve nada: los specs de blindaje
# de este archivo (y el ejemplo gemelo en aislamiento_cross_tenant_spec.rb)
# fallan a propósito si alguien agrega una rama `user.staff?` al Scope.
RSpec.describe CicloMenstrualPolicy do
  let(:usuaria) do
    User.create!(email_address: "usuaria-policy@x.com", password: "clave1234",
                 rol: "miembro", tenant: tenants(:advance_fitness),
                 nombre: "Usuaria Policy", sexo: "F")
  end
  let(:otra) { users(:two) }
  let(:admin) { users(:admin) }
  let(:entrenador) { users(:entrenador) }

  def consentir(user)
    user.consentimientos.create!(tipo: "ciclo_menstrual", accion: "otorgado",
                                 version_texto: "ciclo-v1")
  end

  def ciclo_de(user, inicio = Date.current)
    CicloMenstrual.create!(user:, creado_por: user, fecha_inicio: inicio)
  end

  describe "#create?" do
    let(:registro) { CicloMenstrual.new(user: usuaria, creado_por: usuaria, fecha_inicio: Date.current) }

    it "exige propio + consentimiento vigente" do
      consentir(usuaria)
      expect(described_class.new(usuaria, registro).create?).to be(true)
    end

    it "sin consentimiento no se captura ni un dato" do
      expect(described_class.new(usuaria, registro).create?).to be(false)
    end

    it "con consentimiento revocado tampoco" do
      consentir(usuaria)
      usuaria.consentimientos.create!(tipo: "ciclo_menstrual", accion: "revocado",
                                      version_texto: "ciclo-v1")
      expect(described_class.new(usuaria, registro).create?).to be(false)
    end

    it "nadie crea registros ajenos, tenga o no consentimiento propio" do
      consentir(usuaria)
      consentir(otra)
      expect(described_class.new(otra, registro).create?).to be(false)
      expect(described_class.new(admin, registro).create?).to be(false)
    end
  end

  describe "#show? / #destroy? / #update?" do
    let(:registro) do
      consentir(usuaria)
      ciclo_de(usuaria)
    end

    it "la dueña ve y borra lo suyo — borrar NO exige consentimiento vigente" do
      registro
      usuaria.consentimientos.create!(tipo: "ciclo_menstrual", accion: "revocado",
                                      version_texto: "ciclo-v1")
      policy = described_class.new(usuaria, registro)
      expect(policy.show?).to be(true)
      expect(policy.destroy?).to be(true)
    end

    it "nadie más — ni el staff del propio tenant — ve ni borra" do
      [ otra, admin, entrenador ].each do |quien|
        policy = described_class.new(quien, registro)
        expect(policy.show?).to be(false)
        expect(policy.destroy?).to be(false)
      end
    end

    it "no hay edición para nadie, ni para la dueña (se borra y se re-registra)" do
      expect(described_class.new(usuaria, registro).update?).to be(false)
    end
  end

  describe "Scope — blindaje anti-staff" do
    it "cada quien ve SOLO lo suyo" do
      consentir(usuaria)
      consentir(otra)
      mio = ciclo_de(usuaria)
      ajeno = ciclo_de(otra)

      scope = described_class::Scope.new(usuaria, CicloMenstrual).resolve
      expect(scope).to contain_exactly(mio)
      expect(scope).not_to include(ajeno)
    end

    # BLINDAJE: este ejemplo existe para FALLAR si alguien agrega la rama
    # `user.staff?` (o `del_tenant`) que tienen todas las demás policies.
    # El staff del MISMO tenant, con ciclos existentes en su tenant, debe
    # obtener un scope VACÍO — sin excepciones.
    it "el scope del staff es VACÍO aunque existan ciclos en su tenant" do
      consentir(usuaria)
      ciclo_de(usuaria)

      [ admin, entrenador ].each do |staff|
        expect(described_class::Scope.new(staff, CicloMenstrual).resolve)
          .to be_empty, "el staff #{staff.rol} NO debe ver ciclos ajenos"
      end
    end
  end
end
