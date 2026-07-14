require "rails_helper"

RSpec.describe VencerMembresiasJob, type: :job do
  it "marca vencidas las activas con fecha pasada y no toca el resto" do
    caducada = membresias(:activa_one)
    caducada.update!(fecha_inicio: Date.current - 40, fecha_vencimiento: Date.current - 1)

    al_dia = Membresia.create!(
      user: users(:admin), estado: "activa",
      fecha_inicio: Date.current, fecha_vencimiento: Date.current + 1.month
    )

    VencerMembresiasJob.perform_now

    expect(caducada.reload.estado).to eq("vencida")
    expect(al_dia.reload.estado).to eq("activa")
  end
end
