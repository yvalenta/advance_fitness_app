require "rails_helper"

RSpec.describe Juego::MapaMuscular do
  let(:user) { users(:one) }
  let(:pecho) do
    Ejercicio.create!(dataset_id: "test-pecho", nombre: "Press de banca", nombre_en: "Bench press",
                      nombre_normalizado: "press de banca", categoria: "fuerza", musculo: "pecho")
  end
  let(:pierna) do
    Ejercicio.create!(dataset_id: "test-pierna", nombre: "Sentadilla", nombre_en: "Squat",
                      nombre_normalizado: "sentadilla", categoria: "fuerza", musculo: "pierna")
  end

  def registrar_serie(ejercicio, fecha:, peso_kg:, repeticiones: 10)
    registro = RegistroEntrenamiento.find_or_create_by!(user: user, fecha: fecha)
    registro.detalles.create!(ejercicio: ejercicio, serie: registro.detalles.where(ejercicio: ejercicio).count + 1,
                              repeticiones: repeticiones, peso_kg: peso_kg)
  end

  describe ".para" do
    it "suma el volumen por músculo y deja el resto en cero" do
      registrar_serie(pecho, fecha: Date.current, peso_kg: 60) # 600 kg de volumen

      resultado = described_class.para(user, periodo: :semana)
      expect(resultado[:por_musculo]["pecho"]).to eq(600.0)
      expect(resultado[:por_musculo]["espalda"]).to eq(0.0)
    end

    it "normaliza la intensidad contra el músculo con más volumen" do
      registrar_serie(pecho, fecha: Date.current, peso_kg: 60)    # 600
      registrar_serie(pierna, fecha: Date.current, peso_kg: 120)  # 1200

      resultado = described_class.para(user, periodo: :semana)
      expect(resultado[:intensidad]["pierna"]).to eq(1.0)
      expect(resultado[:intensidad]["pecho"]).to eq(0.5)
    end

    it "lista los músculos sin trabajar, sin incluir 'otro'" do
      registrar_serie(pecho, fecha: Date.current, peso_kg: 60)

      resultado = described_class.para(user, periodo: :semana)
      expect(resultado[:sin_trabajar]).to include("espalda", "pierna")
      expect(resultado[:sin_trabajar]).not_to include("pecho", "otro")
    end

    it "el período 'semana' no cuenta series de hace 2 meses" do
      registrar_serie(pecho, fecha: 60.days.ago.to_date, peso_kg: 60)

      resultado = described_class.para(user, periodo: :semana)
      expect(resultado[:por_musculo]["pecho"]).to eq(0.0)
    end

    it "el período 'todo' sí las cuenta" do
      registrar_serie(pecho, fecha: 60.days.ago.to_date, peso_kg: 60)

      resultado = described_class.para(user, periodo: :todo)
      expect(resultado[:por_musculo]["pecho"]).to eq(600.0)
    end

    it "rechaza un período desconocido" do
      expect { described_class.para(user, periodo: :año) }.to raise_error(ArgumentError)
    end
  end
end
