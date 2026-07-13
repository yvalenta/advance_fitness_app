require "test_helper"

class ResumenAdherenciaTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  def registrar(fecha, ejercicios)
    RegistroEntrenamiento.create!(user: @user, fecha: fecha, ejercicios: ejercicios)
  end

  test "agrega por nombre entre semanas y separa las novedades" do
    lunes = Date.current.beginning_of_week
    registrar(lunes, { "0" => { "hecho" => true, "nombre" => "Press banca" },
                       "1" => { "hecho" => false, "nombre" => "Dominadas" },
                       "novedad" => "me dolió el hombro" })
    registrar(lunes - 1.week, { "0" => { "hecho" => true, "nombre" => "Press banca" } })

    resumen = ResumenAdherencia.para(@user)

    assert_equal 67, resumen[:pct_global]
    press = resumen[:por_ejercicio].find { |e| e[:nombre] == "Press banca" }
    assert_equal({ nombre: "Press banca", hechos: 2, total: 2 }, press)
    assert_equal [ "me dolió el hombro" ], resumen[:novedades]
  end

  test "sin registros devuelve nil y fuera de rango no cuenta" do
    assert_nil ResumenAdherencia.para(@user)

    registrar(Date.current - 10.weeks, { "0" => { "hecho" => true, "nombre" => "Viejo" } })
    assert_nil ResumenAdherencia.para(@user, semanas: 4)
  end

  test "ignora claves no numéricas y limita las novedades a 5" do
    lunes = Date.current.beginning_of_week
    7.times do |i|
      registrar(lunes - i.days, { "novedad" => "nota #{i}", "basura" => { "hecho" => true } })
    end

    resumen = ResumenAdherencia.para(@user)
    assert_equal 5, resumen[:novedades].size
    assert_empty resumen[:por_ejercicio]
  end
end
