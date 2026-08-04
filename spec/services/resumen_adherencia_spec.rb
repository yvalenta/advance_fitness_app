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

  # Fase 14.6: los registros nuevos anclan por uid bajo "items" (v2); los
  # viejos quedan como hechos históricos en v1. El resumen entiende ambos y
  # sigue agrupando por NOMBRE. Lo archivado bajo "legacy" no se cuenta
  # (doble conteo con el re-marcado v2).
  it "mezcla registros v1 y v2 en el mismo resumen" do
    lunes = Date.current.beginning_of_week
    registrar(lunes - 1.week, { "0" => { "hecho" => true, "nombre" => "Press banca" },
                                "novedad" => "banca ocupada" })
    registrar(lunes, { "version" => 2, "novedad" => "hombro al 100", "plan_id" => 7,
                       "legacy" => { "0" => { "hecho" => false, "nombre" => "Press banca" } },
                       "items" => {
                         "uidpress01" => { "hecho" => true, "nombre" => "Press banca", "dia" => 0, "indice" => 0 },
                         "uiddomin02" => { "hecho" => false, "nombre" => "Dominadas", "dia" => 0, "indice" => 1 },
                         "uidsinnom3" => { "hecho" => true, "dia" => 0, "indice" => 4 }
                       } })

    resumen = ResumenAdherencia.para(@user)

    press = resumen[:por_ejercicio].find { |e| e[:nombre] == "Press banca" }
    expect(press).to eq({ nombre: "Press banca", hechos: 2, total: 2 })  # v1 + v2, sin doble conteo del legacy
    expect(resumen[:por_ejercicio].find { |e| e[:nombre] == "Dominadas" }).to eq({ nombre: "Dominadas", hechos: 0, total: 1 })
    # Sin nombre usa el indice histórico del item, no la clave uid
    expect(resumen[:por_ejercicio].find { |e| e[:nombre] == "Ejercicio 5" }).to be_present
    expect(resumen[:pct_global]).to eq(75)  # 3 de 4
    expect(resumen[:novedades]).to eq([ "banca ocupada", "hombro al 100" ])
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
