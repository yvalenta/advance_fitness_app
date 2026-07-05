require "test_helper"

class VencerMembresiasJobTest < ActiveJob::TestCase
  test "marca vencidas las activas con fecha pasada y no toca el resto" do
    caducada = membresias(:activa_one)
    caducada.update!(fecha_inicio: Date.current - 40, fecha_vencimiento: Date.current - 1)

    al_dia = Membresia.create!(
      user: users(:admin), estado: "activa",
      fecha_inicio: Date.current, fecha_vencimiento: Date.current + 1.month
    )

    VencerMembresiasJob.perform_now

    assert_equal "vencida", caducada.reload.estado
    assert_equal "activa", al_dia.reload.estado
  end
end
