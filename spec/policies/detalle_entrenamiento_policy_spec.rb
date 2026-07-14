require "rails_helper"

RSpec.describe DetalleEntrenamientoPolicy do
  let(:dueno) { users(:one) }
  let(:otro) { users(:two) }
  let(:registro) { RegistroEntrenamiento.create!(user: dueno, fecha: Date.current) }

  def premium!(user)
    Suscripcion.create!(user: user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
  end

  describe "#create?" do
    it "niega a un miembro free, incluso siendo el dueño del registro" do
      expect(described_class.new(dueno, registro)).not_to be_create
    end

    it "permite al dueño premium" do
      premium!(dueno)
      expect(described_class.new(dueno, registro)).to be_create
    end

    it "niega a un premium que no es el dueño del registro" do
      premium!(otro)
      expect(described_class.new(otro, registro)).not_to be_create
    end
  end

  describe "#destroy?" do
    let(:ejercicio) do
      Ejercicio.create!(dataset_id: "test-policy-0001", nombre: "Sentadilla", nombre_en: "Squat",
                        nombre_normalizado: "sentadilla", categoria: "fuerza", musculo: "pierna")
    end
    let(:detalle) do
      premium!(dueno)
      registro.detalles.create!(ejercicio: ejercicio, serie: 1, repeticiones: 10, peso_kg: 40)
    end

    it "permite al dueño borrar su propia serie" do
      expect(described_class.new(dueno, detalle)).to be_destroy
    end

    it "niega a otro usuario borrar una serie ajena" do
      expect(described_class.new(otro, detalle)).not_to be_destroy
    end
  end
end
