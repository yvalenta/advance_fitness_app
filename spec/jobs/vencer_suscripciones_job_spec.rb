require "rails_helper"

RSpec.describe VencerSuscripcionesJob, type: :job do
  it "marca expirada la activa con fecha_fin pasada y no toca al día ni VIP" do
    caducada = Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa",
                                   fecha_inicio: Date.current - 40, fecha_fin: Date.current - 1)
    al_dia = Suscripcion.create!(user: users(:admin), plan: planes(:personalizado), estado: "activa",
                                 fecha_inicio: Date.current, fecha_fin: Date.current + 1.month)
    users(:entrenador).update!(vip: true)
    vip = Suscripcion.create!(user: users(:entrenador), plan: planes(:personalizado), estado: "activa",
                              fecha_inicio: Date.current - 40, fecha_fin: Date.current - 1)

    VencerSuscripcionesJob.perform_now

    expect(caducada.reload.estado).to eq("expirada")
    expect(al_dia.reload.estado).to eq("activa")
    expect(vip.reload.estado).to eq("activa")
  end
end
