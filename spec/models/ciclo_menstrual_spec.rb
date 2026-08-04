require "rails_helper"

RSpec.describe CicloMenstrual do
  let(:usuaria) do
    User.create!(email_address: "usuaria-modelo@x.com", password: "clave1234",
                 rol: "miembro", tenant: tenants(:advance_fitness),
                 nombre: "Usuaria Modelo", sexo: "F")
  end
  let(:hoy) { Date.current }

  def consentir(tipo = "ciclo_menstrual", version = "ciclo-v1")
    usuaria.consentimientos.create!(tipo:, accion: "otorgado", version_texto: version)
  end

  def ciclo(inicio = hoy, **attrs)
    described_class.create!(user: usuaria, creado_por: usuaria, fecha_inicio: inicio, **attrs)
  end

  describe "validaciones" do
    it "acepta el caso feliz mínimo (solo fecha de inicio)" do
      expect(ciclo).to be_persisted
    end

    it "rechaza una fecha de inicio futura" do
      registro = described_class.new(user: usuaria, creado_por: usuaria, fecha_inicio: hoy + 1)
      expect(registro).not_to be_valid
      expect(registro.errors[:fecha_inicio]).to include("no puede ser futura")
    end

    it "no duplica el mismo inicio para la misma usuaria" do
      ciclo
      duplicado = described_class.new(user: usuaria, creado_por: usuaria, fecha_inicio: hoy)
      expect(duplicado).not_to be_valid
    end

    it "la misma fecha en OTRA usuaria sí es válida" do
      ciclo
      otra = User.create!(email_address: "otra-modelo@x.com", password: "clave1234",
                          rol: "miembro", tenant: tenants(:advance_fitness), nombre: "Otra")
      expect(described_class.new(user: otra, creado_por: otra, fecha_inicio: hoy)).to be_valid
    end

    it "acota la duración de sangrado a 1..15 días" do
      expect(described_class.new(user: usuaria, creado_por: usuaria, fecha_inicio: hoy,
                                 duracion_sangrado_dias: 0)).not_to be_valid
      expect(described_class.new(user: usuaria, creado_por: usuaria, fecha_inicio: hoy,
                                 duracion_sangrado_dias: 16)).not_to be_valid
    end

    it "la fecha de fin no puede ser anterior al inicio" do
      registro = described_class.new(user: usuaria, creado_por: usuaria,
                                     fecha_inicio: hoy, fecha_fin: hoy - 1)
      expect(registro).not_to be_valid
    end
  end

  describe ".revocar!" do
    it "revoca y BORRA los ciclos, dejando el rastro append-only completo" do
      consentir
      ciclo(hoy - 28)
      ciclo(hoy)

      described_class.revocar!(usuaria)

      expect(usuaria.ciclos_menstruales.count).to eq(0)
      expect(Consentimiento.vigente?(usuaria, "ciclo_menstrual")).to be(false)
      # El rastro NO se borra: queda el otorgado original + la revocación.
      expect(usuaria.consentimientos.where(tipo: "ciclo_menstrual").pluck(:accion))
        .to contain_exactly("otorgado", "revocado")
    end

    it "con conservar_datos: true solo revoca — los registros quedan" do
      consentir
      ciclo

      described_class.revocar!(usuaria, conservar_datos: true)

      expect(usuaria.ciclos_menstruales.count).to eq(1)
      expect(Consentimiento.vigente?(usuaria, "ciclo_menstrual")).to be(false)
    end

    it "revoca también el consentimiento de IA si estaba vigente" do
      consentir
      consentir("ciclo_menstrual_ia", "ciclo-ia-v1")

      described_class.revocar!(usuaria)

      expect(Consentimiento.vigente?(usuaria, "ciclo_menstrual_ia")).to be(false)
    end

    it "no inventa una revocación de IA si nunca se otorgó" do
      consentir

      expect { described_class.revocar!(usuaria) }
        .not_to change { usuaria.consentimientos.where(tipo: "ciclo_menstrual_ia").count }
    end

    it "es TRANSACCIONAL: si el borrado falla, tampoco queda la revocación" do
      consentir
      ciclo
      allow(usuaria).to receive(:ciclos_menstruales)
        .and_raise(ActiveRecord::StatementInvalid.new("boom"))

      expect do
        described_class.revocar!(usuaria)
      rescue ActiveRecord::StatementInvalid
        nil
      end.not_to change(Consentimiento, :count)

      expect(Consentimiento.vigente?(usuaria.reload, "ciclo_menstrual")).to be(true)
    end
  end
end
