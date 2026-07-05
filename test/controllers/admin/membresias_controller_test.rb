require "test_helper"

class Admin::MembresiasControllerTest < ActionDispatch::IntegrationTest
  test "un miembro no accede al listado" do
    sign_in_as users(:one)
    get admin_membresias_path
    assert_redirected_to root_path
  end

  test "el alta crea membresía y primer pago en una transacción" do
    sign_in_as users(:admin)

    assert_difference [ "Membresia.count", "Pago.count" ], 1 do
      post admin_membresias_path, params: { membresia: {
        user_id: users(:entrenador).id,
        fecha_inicio: Date.current,
        monto: 80_000,
        metodo: "efectivo",
        hora_apertura: "06:00",
        hora_cierre: "22:00"
      } }
    end

    membresia = users(:entrenador).reload.membresia
    assert_equal Date.current + 1.month, membresia.fecha_vencimiento
    assert_equal [ "06:00", "22:00" ], membresia.horario_acceso["lun"]
  end

  test "la renovación extiende el vencimiento y registra el pago" do
    sign_in_as users(:admin)
    membresia = membresias(:vencida_two)

    assert_difference "Pago.count", 1 do
      post admin_membresia_renovacion_path(membresia), params: { monto: 80_000, metodo: "tarjeta" }
    end

    membresia.reload
    assert_equal "activa", membresia.estado
    assert_equal Date.current + 1.month, membresia.fecha_vencimiento
  end

  test "un entrenador no puede renovar (solo admin registra pagos)" do
    sign_in_as users(:entrenador)

    assert_no_difference "Pago.count" do
      post admin_membresia_renovacion_path(membresias(:vencida_two)), params: { monto: 80_000, metodo: "efectivo" }
    end
    assert_redirected_to root_path
  end
end
