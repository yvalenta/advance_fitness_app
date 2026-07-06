require "test_helper"

class SuscripcionTest < ActiveSupport::TestCase
  test "solo una suscripción activa por usuario" do
    Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    duplicada = Suscripcion.new(user: users(:one), plan: planes(:free), estado: "activa", fecha_inicio: Date.current)

    assert_not duplicada.valid?
  end

  test "cancelar! cambia el estado y cierra la fecha de fin" do
    suscripcion = Suscripcion.create!(user: users(:one), plan: planes(:personalizado),
                                      estado: "activa", fecha_inicio: Date.current)
    suscripcion.cancelar!

    assert_equal "cancelada", suscripcion.estado
    assert_equal Date.current, suscripcion.fecha_fin
    assert_not users(:one).premium?
  end

  test "premium? refleja la suscripción activa al plan personalizado" do
    assert_not users(:one).premium?
    Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    assert users(:one).reload.premium?
  end
end
