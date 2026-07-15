require "rails_helper"

RSpec.describe "Admin::Membresias", type: :request do
  it "un miembro no accede al listado" do
    sign_in_as users(:one)
    get admin_membresias_path
    expect(response).to redirect_to(root_path)
  end

  it "el alta crea membresía y primer pago en una transacción" do
    sign_in_as users(:admin)

    expect {
      post admin_membresias_path, params: { membresia: {
        user_id: users(:entrenador).id,
        fecha_inicio: Date.current,
        monto: 80_000,
        metodo: "efectivo"
      } }
    }.to change(Membresia, :count).by(1).and change(Pago, :count).by(1)

    membresia = users(:entrenador).reload.membresia
    expect(membresia.fecha_vencimiento).to eq(Date.current + 30.days)
    expect(users(:entrenador).premium?).to be_falsey
  end

  it "el alta con el monto del combo (350.000) incluye la suscripción sin cobro aparte" do
    sign_in_as users(:admin)

    expect {
      post admin_membresias_path, params: { membresia: {
        user_id: users(:entrenador).id,
        fecha_inicio: Date.current,
        monto: Negocio.precio_personalizado,
        metodo: "efectivo"
      } }
    }.to change(Suscripcion, :count).by(1)

    expect(users(:entrenador).reload.premium?).to be_truthy
    suscripcion = users(:entrenador).suscripcion_activa
    expect(suscripcion.incluida_en_membresia?).to be_truthy
    expect(suscripcion.membresia).to eq(users(:entrenador).membresia)
  end

  it "la renovación extiende el vencimiento y registra el pago" do
    sign_in_as users(:admin)
    membresia = membresias(:vencida_two)

    expect {
      post admin_membresia_renovacion_path(membresia), params: { monto: 80_000, metodo: "tarjeta" }
    }.to change(Pago, :count).by(1)

    membresia.reload
    expect(membresia.estado).to eq("activa")
    expect(membresia.fecha_vencimiento).to eq(Date.current + 30.days)
  end

  # Fase 6.13: buscador en vivo por nombre/correo del miembro
  it "el listado filtra por usuario con ?q=" do
    sign_in_as users(:admin)

    get admin_membresias_path(q: users(:one).nombre)

    expect(response).to have_http_status(:success)
    expect(response.body).to include(users(:one).email_address)
    expect(response.body).not_to include(users(:two).email_address)
  end

  it "el link al miembro rompe el turbo_frame del buscador" do
    sign_in_as users(:admin)
    get admin_membresias_path
    assert_select "a[href=?][data-turbo-frame=?]", admin_user_path(membresias(:vencida_two).user), "_top"
  end

  it "el link Gestionar rompe el turbo_frame del buscador (si no, Turbo muestra Content missing)" do
    sign_in_as users(:admin)
    get admin_membresias_path
    assert_select "a[href=?][data-turbo-frame=?]", edit_admin_membresia_path(membresias(:vencida_two)), "_top"
  end

  it "un entrenador no puede renovar (solo admin registra pagos)" do
    sign_in_as users(:entrenador)

    expect {
      post admin_membresia_renovacion_path(membresias(:vencida_two)), params: { monto: 80_000, metodo: "efectivo" }
    }.not_to change(Pago, :count)
    expect(response).to redirect_to(root_path)
  end
end
