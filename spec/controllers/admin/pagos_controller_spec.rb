require "rails_helper"

RSpec.describe "Admin::Pagos", type: :request do
  it "el admin corrige monto y método de un pago vigente" do
    sign_in_as users(:admin)

    patch admin_pago_path(pagos(:inicial_one)), params: { pago: { monto: 85_000, metodo: "transferencia" } }

    expect(response).to redirect_to(admin_pagos_path)
    expect(pagos(:inicial_one).reload.monto.to_i).to eq(85_000)
    expect(pagos(:inicial_one).metodo).to eq("transferencia")
  end

  it "eliminar un pago lo anula y sigue figurando en el historial" do
    sign_in_as users(:admin)

    expect {
      delete admin_pago_path(pagos(:inicial_one))
    }.not_to change(Pago, :count)
    expect(pagos(:inicial_one).reload.anulado?).to be_truthy

    get admin_pagos_path
    expect(response.body).to include("eliminado")
  end

  it "un pago anulado no se puede editar ni volver a eliminar" do
    pagos(:inicial_one).anular!(por: users(:admin))
    sign_in_as users(:admin)

    patch admin_pago_path(pagos(:inicial_one)), params: { pago: { monto: 90_000 } }
    expect(response).to redirect_to(root_path) # policy lo bloquea

    expect(pagos(:inicial_one).reload.monto.to_i).to eq(80_000)
  end

  # Fase 6.13: un solo campo interpreta usuario, fecha, valor o método
  it "el buscador filtra por método" do
    sign_in_as users(:admin)
    get admin_pagos_path(q: "efectivo")
    expect(response).to have_http_status(:success)
    expect(response.body).to include("80.000")
  end

  it "el buscador filtra por valor" do
    sign_in_as users(:admin)
    get admin_pagos_path(q: "80000")
    expect(response).to have_http_status(:success)
    expect(response.body).to include("80.000")

    get admin_pagos_path(q: "99999")
    expect(response).to have_http_status(:success)
    expect(response.body).not_to include("80.000")
  end

  it "el buscador filtra por miembro" do
    sign_in_as users(:admin)
    get admin_pagos_path(q: pagos(:inicial_one).membresia.user.nombre)
    expect(response).to have_http_status(:success)
    expect(response.body).to include("80.000")
  end

  # El link al miembro vive dentro del turbo_frame del buscador; sin
  # data-turbo-frame="_top" Turbo lo trata como navegación DE frame y
  # revienta con "Content missing" (Fase 6.14).
  it "el link al miembro rompe el turbo_frame del buscador" do
    sign_in_as users(:admin)
    get admin_pagos_path
    assert_select "a[href=?][data-turbo-frame=?]", admin_user_path(pagos(:inicial_one).membresia.user), "_top"
  end

  it "el link Editar rompe el turbo_frame del buscador" do
    sign_in_as users(:admin)
    get admin_pagos_path
    assert_select "a[href=?][data-turbo-frame=?]", edit_admin_pago_path(pagos(:inicial_one)), "_top"
  end

  it "el entrenador no corrige ni elimina pagos" do
    sign_in_as users(:entrenador)

    patch admin_pago_path(pagos(:inicial_one)), params: { pago: { monto: 90_000 } }
    expect(response).to redirect_to(root_path)

    delete admin_pago_path(pagos(:inicial_one))
    expect(response).to redirect_to(root_path)
    expect(pagos(:inicial_one).reload.anulado?).to be_falsey
  end
end
