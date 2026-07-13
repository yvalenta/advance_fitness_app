require "test_helper"

class Admin::PagosControllerTest < ActionDispatch::IntegrationTest
  test "el admin corrige monto y método de un pago vigente" do
    sign_in_as users(:admin)

    patch admin_pago_path(pagos(:inicial_one)), params: { pago: { monto: 85_000, metodo: "transferencia" } }

    assert_redirected_to admin_pagos_path
    assert_equal 85_000, pagos(:inicial_one).reload.monto.to_i
    assert_equal "transferencia", pagos(:inicial_one).metodo
  end

  test "eliminar un pago lo anula y sigue figurando en el historial" do
    sign_in_as users(:admin)

    assert_no_difference "Pago.count" do
      delete admin_pago_path(pagos(:inicial_one))
    end
    assert pagos(:inicial_one).reload.anulado?

    get admin_pagos_path
    assert_match "eliminado", response.body
  end

  test "un pago anulado no se puede editar ni volver a eliminar" do
    pagos(:inicial_one).anular!(por: users(:admin))
    sign_in_as users(:admin)

    patch admin_pago_path(pagos(:inicial_one)), params: { pago: { monto: 90_000 } }
    assert_redirected_to root_path # policy lo bloquea

    assert_equal 80_000, pagos(:inicial_one).reload.monto.to_i
  end

  # Fase 6.13: un solo campo interpreta usuario, fecha, valor o método
  test "el buscador filtra por método" do
    sign_in_as users(:admin)
    get admin_pagos_path(q: "efectivo")
    assert_response :success
    assert_match "80.000", response.body
  end

  test "el buscador filtra por valor" do
    sign_in_as users(:admin)
    get admin_pagos_path(q: "80000")
    assert_response :success
    assert_match "80.000", response.body

    get admin_pagos_path(q: "99999")
    assert_response :success
    assert_no_match "80.000", response.body
  end

  test "el buscador filtra por miembro" do
    sign_in_as users(:admin)
    get admin_pagos_path(q: pagos(:inicial_one).membresia.user.nombre)
    assert_response :success
    assert_match "80.000", response.body
  end

  # El link al miembro vive dentro del turbo_frame del buscador; sin
  # data-turbo-frame="_top" Turbo lo trata como navegación DE frame y
  # revienta con "Content missing" (Fase 6.14).
  test "el link al miembro rompe el turbo_frame del buscador" do
    sign_in_as users(:admin)
    get admin_pagos_path
    assert_select "a[href=?][data-turbo-frame=?]", admin_user_path(pagos(:inicial_one).membresia.user), "_top"
  end

  test "el entrenador no corrige ni elimina pagos" do
    sign_in_as users(:entrenador)

    patch admin_pago_path(pagos(:inicial_one)), params: { pago: { monto: 90_000 } }
    assert_redirected_to root_path

    delete admin_pago_path(pagos(:inicial_one))
    assert_redirected_to root_path
    assert_not pagos(:inicial_one).reload.anulado?
  end
end
