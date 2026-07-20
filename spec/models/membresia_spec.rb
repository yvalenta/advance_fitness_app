require "rails_helper"

RSpec.describe Membresia, type: :model do
  it "renovar! extiende el vencimiento, activa y registra el pago" do
    membresia = membresias(:vencida_two)

    expect {
      membresia.renovar!(monto: 80_000, metodo: "efectivo", registrado_por: users(:admin))
    }.to change(Pago, :count).by(1)

    expect(membresia.estado).to eq("activa")
    expect(membresia.fecha_vencimiento).to eq(Date.current + 30.days)

    pago = membresia.pagos.order(:id).last
    expect(pago.periodo_inicio).to eq(Date.current)
    expect(pago.periodo_fin).to eq(membresia.fecha_vencimiento)
  end

  it "renovar! de una activa extiende desde el vencimiento vigente" do
    membresia = membresias(:activa_one)
    vencimiento_original = membresia.fecha_vencimiento

    membresia.renovar!(monto: 80_000, metodo: "tarjeta", registrado_por: users(:admin))

    expect(membresia.fecha_vencimiento).to eq(vencimiento_original + 30.days)
  end

  it "para_vencer solo incluye activas con fecha pasada" do
    membresias(:activa_one).update!(fecha_vencimiento: Date.current - 1, fecha_inicio: Date.current - 40)

    expect(Membresia.para_vencer).to include(membresias(:activa_one))
    expect(Membresia.para_vencer).not_to include(membresias(:vencida_two))
  end

  it "VIP: activa? es verdadero y para_vencer la excluye aunque esté vencida (Fase 12.2)" do
    membresia = membresias(:activa_one)
    membresia.update!(fecha_vencimiento: Date.current - 1, fecha_inicio: Date.current - 40)
    membresia.user.update!(vip: true)

    expect(membresia.activa?).to be_truthy
    expect(Membresia.para_vencer).not_to include(membresia)
  end

  it "el vencimiento debe ser posterior al inicio" do
    membresia = Membresia.new(user: users(:admin), fecha_inicio: Date.current, fecha_vencimiento: Date.current)
    expect(membresia.valid?).to be_falsey
  end

  # Fase 5.11: el historial pasó de inmutable a auditable — un monto irrisorio
  # sigue sin ser válido y la anulación reemplaza al borrado (ver pago_spec).
  it "los pagos no aceptan montos irrisorios" do
    pago = pagos(:inicial_one)
    expect { pago.update!(monto: 1) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
