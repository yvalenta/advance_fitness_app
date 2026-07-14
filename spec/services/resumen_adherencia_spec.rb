require "rails_helper"

RSpec.describe ResumenAdherencia, type: :model do
  before { @user = users(:one) }

  def registrar(fecha, ejercicios)
    RegistroEntrenamiento.create!(user: @user, fecha: fecha, ejercicios: ejercicios)
  end

  it "agrega por nombre entre semanas y separa las novedades" do
    lunes = Date.current.beginning_of_week
    registrar(lunes, { "0" => { "hecho" => true, "nombre" => "Press banca" },
                       "1" => { "hecho" => false, "nombre" => "Dominadas" },
                       "novedad" => "me dolió el hombro" })
    registrar(lunes - 1.week, { "0" => { "hecho" => true, "nombre" => "Press banca" } })

    resumen = ResumenAdherencia.para(@user)

    expect(resumen[:pct_global]).to eq(67)
    press = resumen[:por_ejercicio].find { |e| e[:nombre] == "Press banca" }
    expect(press).to eq({ nombre: "Press banca", hechos: 2, total: 2 })
    expect(resumen[:novedades]).to eq([ "me dolió el hombro" ])
  end

  it "sin registros devuelve nil y fuera de rango no cuenta" do
    expect(ResumenAdherencia.para(@user)).to be_nil

    registrar(Date.current - 10.weeks, { "0" => { "hecho" => true, "nombre" => "Viejo" } })
    expect(ResumenAdherencia.para(@user, semanas: 4)).to be_nil
  end

  it "ignora claves no numéricas y limita las novedades a 5" do
    lunes = Date.current.beginning_of_week
    7.times do |i|
      registrar(lunes - i.days, { "novedad" => "nota #{i}", "basura" => { "hecho" => true } })
    end

    resumen = ResumenAdherencia.para(@user)
    expect(resumen[:novedades].size).to eq(5)
    expect(resumen[:por_ejercicio]).to be_empty
  end
end
