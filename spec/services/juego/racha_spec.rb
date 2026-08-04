require "rails_helper"

RSpec.describe Juego::Racha do
  let(:user) { users(:one) }
  let(:hoy) { Date.current }

  it "el día consecutivo incrementa la racha" do
    described_class.actualizar!(user, fecha: hoy - 1)
    perfil = described_class.actualizar!(user, fecha: hoy)

    expect(perfil.racha_actual).to eq 2
    expect(perfil.racha_mejor).to eq 2
    expect(perfil.ultima_fecha_racha).to eq hoy
  end

  it "un hueco resetea la racha a 1 pero conserva la mejor" do
    described_class.actualizar!(user, fecha: hoy - 5)
    described_class.actualizar!(user, fecha: hoy - 4)
    described_class.actualizar!(user, fecha: hoy - 3)
    perfil = described_class.actualizar!(user, fecha: hoy) # hueco de 2 días

    expect(perfil.racha_actual).to eq 1
    expect(perfil.racha_mejor).to eq 3
  end

  it "el mismo día repetido es no-op (idempotente)" do
    described_class.actualizar!(user, fecha: hoy - 1)
    described_class.actualizar!(user, fecha: hoy)
    perfil = described_class.actualizar!(user, fecha: hoy)

    expect(perfil.racha_actual).to eq 2
    expect(perfil.ultima_fecha_racha).to eq hoy
  end

  it "marcar un día PASADO no rompe la racha vigente (no-op hacia atrás)" do
    described_class.actualizar!(user, fecha: hoy - 1)
    described_class.actualizar!(user, fecha: hoy)
    perfil = described_class.actualizar!(user, fecha: hoy - 10)

    expect(perfil.racha_actual).to eq 2
    expect(perfil.ultima_fecha_racha).to eq hoy
  end
end
