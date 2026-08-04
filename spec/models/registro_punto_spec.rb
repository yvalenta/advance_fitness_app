require "rails_helper"

RSpec.describe RegistroPunto, type: :model do
  let(:user) { users(:one) }
  let(:admin) { users(:admin) }
  let(:acceso) { Acceso.create!(user: user, fecha_hora: Time.current) }

  it "valida tipo, puntos entero distinto de cero y fecha" do
    valido = RegistroPunto.new(user: user, tipo: "checkin", puntos: 10, fecha: Date.current)
    expect(valido).to be_valid

    expect(RegistroPunto.new(user: user, tipo: "otro", puntos: 10, fecha: Date.current)).not_to be_valid
    expect(RegistroPunto.new(user: user, tipo: "checkin", puntos: 0, fecha: Date.current)).not_to be_valid
    expect(RegistroPunto.new(user: user, tipo: "checkin", puntos: 10, fecha: nil)).not_to be_valid
  end

  it "ajuste_manual exige creado_por (autor humano); puede ser negativo" do
    sin_autor = RegistroPunto.new(user: user, tipo: "ajuste_manual", puntos: -50, fecha: Date.current)
    expect(sin_autor).not_to be_valid
    expect(sin_autor.errors[:creado_por]).to be_present

    con_autor = RegistroPunto.new(user: user, tipo: "ajuste_manual", puntos: -50,
                                  fecha: Date.current, creado_por: admin)
    expect(con_autor).to be_valid
  end

  it "es append-only: una fila persistida no se edita ni se borra" do
    fila = RegistroPunto.create!(user: user, tipo: "checkin", puntos: 10, fecha: Date.current)

    expect { fila.update!(puntos: 999) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { fila.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "la constraint única parcial rechaza el mismo (user, tipo, origen) en la BASE" do
    RegistroPunto.create!(user: user, tipo: "checkin", puntos: 10, fecha: Date.current, origen: acceso)

    expect {
      RegistroPunto.create!(user: user, tipo: "checkin", puntos: 10, fecha: Date.current, origen: acceso)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "la constraint es parcial: filas sin origen (ajuste_manual) no chocan entre sí" do
    2.times do
      RegistroPunto.create!(user: user, tipo: "ajuste_manual", puntos: 5,
                            fecha: Date.current, creado_por: admin)
    end
    expect(user.registros_puntos.count).to eq 2
  end

  it "origenes distintos del mismo tipo sí conviven (dos check-ins reales)" do
    otro_acceso = Acceso.create!(user: user, fecha_hora: Time.current + 1.hour)
    RegistroPunto.create!(user: user, tipo: "checkin", puntos: 10, fecha: Date.current, origen: acceso)
    RegistroPunto.create!(user: user, tipo: "checkin", puntos: 10, fecha: Date.current, origen: otro_acceso)

    expect(user.registros_puntos.count).to eq 2
  end
end
