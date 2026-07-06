require "test_helper"

class Admin::SuscripcionesControllerTest < ActionDispatch::IntegrationTest
  test "un miembro no accede a suscripciones" do
    sign_in_as users(:one)
    get admin_suscripciones_path
    assert_redirected_to root_path
  end

  test "un entrenador tampoco registra suscripciones (solo admin)" do
    sign_in_as users(:entrenador)

    assert_no_difference "Suscripcion.count" do
      post admin_suscripciones_path, params: { suscripcion: { user_id: users(:one).id, fecha_inicio: Date.current } }
    end
    assert_redirected_to root_path
  end

  test "el alta crea la suscripción personalizada y encola la generación con IA" do
    sign_in_as users(:admin)

    assert_difference "Suscripcion.count", 1 do
      post admin_suscripciones_path, params: { suscripcion: { user_id: users(:one).id, fecha_inicio: Date.current } }
    end

    suscripcion = Suscripcion.last
    assert_equal planes(:personalizado), suscripcion.plan
    assert suscripcion.activa?
    assert_enqueued_with(job: GenerarPlanJob, args: [ users(:one).id ])
  end

  test "cancelar deja al miembro sin premium" do
    sign_in_as users(:admin)
    suscripcion = Suscripcion.create!(user: users(:one), plan: planes(:personalizado),
                                      estado: "activa", fecha_inicio: Date.current)

    patch admin_suscripcion_path(suscripcion)

    assert_equal "cancelada", suscripcion.reload.estado
    assert_not users(:one).premium?
  end
end
