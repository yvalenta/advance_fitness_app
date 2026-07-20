require "rails_helper"

RSpec.describe Suscripcion, type: :model do
  it "solo una suscripción activa por usuario" do
    Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    duplicada = Suscripcion.new(user: users(:one), plan: planes(:free), estado: "activa", fecha_inicio: Date.current)

    expect(duplicada.valid?).to be_falsey
  end

  it "cancelar! cambia el estado y cierra la fecha de fin" do
    suscripcion = Suscripcion.create!(user: users(:one), plan: planes(:personalizado),
                                      estado: "activa", fecha_inicio: Date.current)
    suscripcion.cancelar!

    expect(suscripcion.estado).to eq("cancelada")
    expect(suscripcion.fecha_fin).to eq(Date.current)
    expect(users(:one).premium?).to be_falsey
  end

  it "premium? refleja la suscripción activa al plan personalizado" do
    expect(users(:one).premium?).to be_falsey
    Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    expect(users(:one).reload.premium?).to be_truthy
  end

  it "incluir_con_membresia! crea la suscripción activa si el monto cubre el Personalizado" do
    membresia = membresias(:activa_one)
    membresia.pagos.create!(monto: Negocio.precio_personalizado, metodo: "efectivo",
                            registrado_por: users(:entrenador), fecha_pago: Date.current,
                            periodo_inicio: Date.current, periodo_fin: Date.current + 30)

    expect {
      Suscripcion.incluir_con_membresia!(membresia)
    }.to change { Suscripcion.count }.by(1)

    suscripcion = membresia.user.suscripcion_activa
    expect(suscripcion.activa?).to be_truthy
    expect(suscripcion.incluida_en_membresia?).to be_truthy
    expect(suscripcion.membresia).to eq(membresia)
    expect(suscripcion.plan).to eq(planes(:personalizado))
  end

  it "incluir_con_membresia! no hace nada si el monto no cubre el Personalizado" do
    membresia = membresias(:activa_one) # su pago fixture es de 80.000

    expect {
      Suscripcion.incluir_con_membresia!(membresia)
    }.not_to change { Suscripcion.count }
  end

  it "incluir_con_membresia! programa la siguiente si ya hay una activa con fin" do
    membresia = membresias(:activa_one)
    membresia.pagos.create!(monto: Negocio.precio_personalizado, metodo: "efectivo",
                            registrado_por: users(:entrenador), fecha_pago: Date.current,
                            periodo_inicio: Date.current, periodo_fin: Date.current + 30)
    activa = Suscripcion.create!(user: membresia.user, plan: planes(:personalizado),
                                estado: "activa", fecha_inicio: Date.current - 10, fecha_fin: Date.current + 5)

    expect {
      Suscripcion.incluir_con_membresia!(membresia)
    }.to change { Suscripcion.count }.by(1)

    programada = membresia.user.suscripciones.programadas.first
    expect(programada.fecha_inicio).to eq(activa.fecha_fin + 1.day)
    expect(programada.incluida_en_membresia?).to be_truthy
  end

  it "fija fecha_fin a un mes desde el inicio si no se especifica (Fase 12.2)" do
    suscripcion = Suscripcion.create!(user: users(:one), plan: planes(:personalizado),
                                      estado: "activa", fecha_inicio: Date.current)

    expect(suscripcion.fecha_fin).to eq(Date.current + Negocio.duracion_dias.days)
  end

  it "VIP: activa? siempre es verdadero aunque la fecha_fin ya haya pasado" do
    users(:one).update!(vip: true)
    suscripcion = Suscripcion.create!(user: users(:one), plan: planes(:personalizado),
                                      estado: "activa", fecha_inicio: Date.current - 40,
                                      fecha_fin: Date.current - 10)

    expect(suscripcion.activa?).to be_truthy
    expect(Suscripcion.para_vencer).not_to include(suscripcion)
  end

  it "para_vencer incluye una suscripción activa no-VIP vencida" do
    suscripcion = Suscripcion.create!(user: users(:one), plan: planes(:personalizado),
                                      estado: "activa", fecha_inicio: Date.current - 40,
                                      fecha_fin: Date.current - 10)

    expect(Suscripcion.para_vencer).to include(suscripcion)
  end

  it "activar_programadas! activa las que llegaron su turno y expira la anterior" do
    membresia = membresias(:activa_one)
    anterior = Suscripcion.create!(user: membresia.user, plan: planes(:personalizado), estado: "activa",
                                  fecha_inicio: Date.current - 10, fecha_fin: Date.current - 1)
    programada = Suscripcion.create!(user: membresia.user, plan: planes(:personalizado), membresia: membresia,
                                    estado: "programada", fecha_inicio: Date.current)

    Suscripcion.activar_programadas!

    expect(programada.reload.estado).to eq("activa")
    expect(anterior.reload.estado).to eq("expirada")
  end
end
