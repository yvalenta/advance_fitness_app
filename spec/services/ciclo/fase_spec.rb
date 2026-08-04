require "rails_helper"

# La fase se DERIVA, jamás se persiste (principio User#edad), y es
# fail-closed: sin consentimiento vigente o sin datos → :desconocida.
RSpec.describe Ciclo::Fase do
  let(:usuaria) do
    User.create!(email_address: "usuaria-fase@x.com", password: "clave1234",
                 rol: "miembro", tenant: tenants(:advance_fitness),
                 nombre: "Usuaria Fase", sexo: "F")
  end
  let(:hoy) { Date.current }

  def consentir
    usuaria.consentimientos.create!(tipo: "ciclo_menstrual", accion: "otorgado",
                                    version_texto: "ciclo-v1")
  end

  def revocar
    usuaria.consentimientos.create!(tipo: "ciclo_menstrual", accion: "revocado",
                                    version_texto: "ciclo-v1")
  end

  def ciclo(inicio, **attrs)
    CicloMenstrual.create!(user: usuaria, creado_por: usuaria, fecha_inicio: inicio, **attrs)
  end

  describe "fail-closed (privacidad primero)" do
    it "sin consentimiento vigente → :desconocida aunque existan datos" do
      ciclo(hoy)
      expect(described_class.para(usuaria)).to eq(:desconocida)
      expect(described_class.proxima_menstruacion(usuaria)).to be_nil
      expect(described_class.dia_del_ciclo(usuaria)).to be_nil
    end

    it "consentimiento revocado → :desconocida (la última fila manda)" do
      consentir
      ciclo(hoy)
      revocar
      expect(described_class.para(usuaria)).to eq(:desconocida)
    end

    it "con consentimiento pero sin datos → :desconocida" do
      consentir
      expect(described_class.para(usuaria)).to eq(:desconocida)
      expect(described_class.proxima_menstruacion(usuaria)).to be_nil
    end
  end

  describe "fases con un solo ciclo (largo default 28, sangrado default 5)" do
    before { consentir }

    {
      0 => :menstrual,   # día 1
      4 => :menstrual,   # día 5 (último de sangrado default)
      5 => :folicular,   # día 6
      11 => :folicular,  # día 12
      12 => :ovulacion,  # día 13 (ventana 13..15 alrededor del día 14)
      14 => :ovulacion,  # día 15
      15 => :lutea,      # día 16
      27 => :lutea,      # día 28
      34 => :lutea       # día 35 = 28 + tolerancia de retraso
    }.each do |dias_atras, esperada|
      it "inicio hace #{dias_atras} días → :#{esperada}" do
        ciclo(hoy - dias_atras)
        expect(described_class.para(usuaria)).to eq(esperada)
      end
    end

    it "pasada la tolerancia de retraso ya no se estima → :desconocida" do
      ciclo(hoy - 35) # día 36 > 28 + 7
      expect(described_class.para(usuaria)).to eq(:desconocida)
    end

    it "respeta la duración de sangrado registrada por la usuaria" do
      ciclo(hoy - 5, duracion_sangrado_dias: 7) # día 6, sangrado 7 → sigue menstrual
      expect(described_class.para(usuaria)).to eq(:menstrual)
    end
  end

  describe "largo estimado con historial" do
    before { consentir }

    it "ciclos regulares: promedio de las separaciones (30 días)" do
      [ hoy - 90, hoy - 60, hoy - 30, hoy ].each { |inicio| ciclo(inicio) }
      expect(described_class.duracion_estimada(usuaria)).to eq(30)
      expect(described_class.proxima_menstruacion(usuaria)).to eq(hoy + 30)
      expect(described_class.para(usuaria)).to eq(:menstrual) # día 1
    end

    it "ciclos irregulares: promedia gaps distintos (26, 30, 34 → 30)" do
      [ hoy - 90, hoy - 64, hoy - 34, hoy ].each { |inicio| ciclo(inicio) }
      expect(described_class.duracion_estimada(usuaria)).to eq(30)
    end

    it "un gap inverosímil (meses sin registrar) no arrastra el promedio" do
      [ hoy - 118, hoy - 28, hoy ].each { |inicio| ciclo(inicio) } # gaps 90 y 28
      expect(described_class.duracion_estimada(usuaria)).to eq(28)
    end

    it "sin ningún gap verosímil cae al default 28" do
      [ hoy - 100, hoy ].each { |inicio| ciclo(inicio) }
      expect(described_class.duracion_estimada(usuaria)).to eq(28)
    end
  end

  describe "consultas a una fecha dada (no solo hoy)" do
    before { consentir }

    it "usa el último inicio ANTERIOR a la fecha y su historial hasta entonces" do
      ciclo(hoy - 30)
      ciclo(hoy)
      # A hoy-25 solo existía el ciclo de hoy-30: día 6 con largo default 28.
      expect(described_class.dia_del_ciclo(usuaria, hoy - 25)).to eq(6)
      expect(described_class.para(usuaria, hoy - 25)).to eq(:folicular)
    end
  end
end
