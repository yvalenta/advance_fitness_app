require "rails_helper"

RSpec.describe Juego::Heatmap do
  let(:user) { users(:one) }
  let(:hoy) { Date.current }

  def marcar_hecho(fecha)
    registro = RegistroEntrenamiento.create!(user: user, fecha: fecha)
    registro.marcar!(uid: "abc123", hecho: true, nombre: "Sentadilla", dia: 0, indice: 0)
  end

  describe ".para" do
    it "nivel 0 sin check-in ni ejercicios marcados" do
      dias = described_class.para(user, desde: hoy, hasta: hoy)
      expect(dias).to eq([ { fecha: hoy, nivel: 0 } ])
    end

    it "nivel 1 con check-in solamente" do
      user.accesos.create!(fecha_hora: Time.current.change(hour: 10), tipo: "checkin", dentro_de_horario: true)

      dias = described_class.para(user, desde: hoy, hasta: hoy)
      expect(dias.first[:nivel]).to eq(1)
    end

    it "nivel 2 con un ejercicio marcado hecho, sin check-in" do
      marcar_hecho(hoy)

      dias = described_class.para(user, desde: hoy, hasta: hoy)
      expect(dias.first[:nivel]).to eq(2)
    end

    it "nivel 3 con check-in Y ejercicio marcado" do
      user.accesos.create!(fecha_hora: Time.current.change(hour: 10), tipo: "checkin", dentro_de_horario: true)
      marcar_hecho(hoy)

      dias = described_class.para(user, desde: hoy, hasta: hoy)
      expect(dias.first[:nivel]).to eq(3)
    end
  end

  describe ".en_columnas" do
    it "agrupa en columnas de 7 días alineadas a la semana (lunes-domingo)" do
      dias = described_class.para(user, desde: hoy.beginning_of_week, hasta: hoy.beginning_of_week + 6)

      columnas = described_class.en_columnas(dias)
      expect(columnas.size).to eq(1)
      expect(columnas.first.size).to eq(7)
    end

    it "devuelve vacío sin datos" do
      expect(described_class.en_columnas([])).to eq([])
    end
  end
end
