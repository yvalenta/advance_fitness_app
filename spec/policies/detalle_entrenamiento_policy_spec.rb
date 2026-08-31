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

  describe "#analizar?" do
    let(:entrenador) { users(:entrenador) }

    it "staff sí, sobre un registro de su gimnasio; el miembro no" do
      expect(described_class.new(entrenador, registro).analizar?).to be true
      expect(described_class.new(dueno, registro).analizar?).to be false
    end

    # Defensa en profundidad (tarea 2026-08-31): el rol ya no basta — el
    # DUEÑO del registro debe tener puesto en el gimnasio del staff. Este es
    # el check que frena a un controller descuidado con un find crudo.
    it "el staff de A no analiza el registro de un miembro de B, aunque sea staff" do
      miembro_mp = User.create!(email_address: "miembro-mp-registro@x.com", password: "clave1234",
                                rol: "miembro", tenant: tenants(:megaplex), nombre: "Miembro MP")
      registro_mp = RegistroEntrenamiento.create!(user: miembro_mp, fecha: Date.current)

      expect(described_class.new(entrenador, registro_mp).analizar?).to be false
      expect(described_class.new(users(:admin), registro_mp).analizar?).to be false
    end
  end
end
