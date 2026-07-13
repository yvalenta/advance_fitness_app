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
      post admin_suscripciones_path, params: {
        suscripcion: { user_id: users(:one).id, fecha_inicio: Date.current }, medicion: { peso_kg: 70 }
      }
    end
    assert_redirected_to root_path
  end

  test "el alta crea la suscripción, la medición y encola la generación con IA" do
    sign_in_as users(:admin)

    assert_difference [ "Suscripcion.count", "PlanPersonalizado.count", "Medicion.count" ], 1 do
      post admin_suscripciones_path, params: {
        suscripcion: { user_id: users(:one).id, fecha_inicio: Date.current },
        medicion: { peso_kg: 72.5, cintura_cm: 82, pliegue_abdominal_mm: 14 }
      }
    end

    suscripcion = Suscripcion.last
    assert_equal planes(:personalizado), suscripcion.plan
    assert suscripcion.activa?

    medicion = users(:one).ultima_medicion
    assert_equal 72.5, medicion.peso_kg.to_f
    assert_equal users(:admin), medicion.tomada_por

    plan = users(:one).planes_personalizados.last
    assert plan.generando?
    assert_enqueued_with(job: GenerarPlanJob, args: [ plan.id ])
  end

  # Fase 5.11: la membresía va incluida con la suscripción
  test "el alta reactiva la membresía vencida del miembro" do
    sign_in_as users(:admin)

    post admin_suscripciones_path, params: {
      suscripcion: { user_id: users(:two).id, fecha_inicio: Date.current },
      medicion: { peso_kg: 68 }
    }

    membresia = users(:two).membresia.reload
    assert membresia.activa?
    assert_equal Date.current + Membresia.duracion, membresia.fecha_vencimiento
  end

  test "el alta crea la membresía si el miembro no tiene (incluida, sin pago)" do
    users(:entrenador).update!(rol: "miembro") # un user sin membresía
    sign_in_as users(:admin)

    assert_difference "Membresia.count", 1 do
      assert_no_difference "Pago.count" do
        post admin_suscripciones_path, params: {
          suscripcion: { user_id: users(:entrenador).id, fecha_inicio: Date.current },
          medicion: { peso_kg: 80 }
        }
      end
    end
    assert users(:entrenador).membresia.activa?
  end

  # Fase 5.16: reintentar el alta el mismo día (p. ej. tras un fallo previo)
  # no debe chocar con el índice único user_id+fecha de mediciones.
  test "si el miembro ya tiene medición hoy, el alta la corrige en vez de fallar" do
    users(:one).mediciones.create!(fecha: Date.current, peso_kg: 70, tomada_por: users(:admin))
    sign_in_as users(:admin)

    assert_difference [ "Suscripcion.count", "PlanPersonalizado.count" ], 1 do
      assert_no_difference "Medicion.count" do
        post admin_suscripciones_path, params: {
          suscripcion: { user_id: users(:one).id, fecha_inicio: Date.current },
          medicion: { peso_kg: 73.5 }
        }
      end
    end

    assert_response :redirect
    assert users(:one).suscripciones.last.activa?
    assert_equal 73.5, users(:one).ultima_medicion.peso_kg.to_f
    assert users(:one).membresia.activa? # la regla de negocio sigue aplicando
  end

  test "sin peso en la medición no crea la suscripción ni encola" do
    sign_in_as users(:admin)

    assert_no_difference [ "Suscripcion.count", "Medicion.count", "PlanPersonalizado.count" ] do
      assert_no_enqueued_jobs only: GenerarPlanJob do
        post admin_suscripciones_path, params: {
          suscripcion: { user_id: users(:one).id, fecha_inicio: Date.current }, medicion: { peso_kg: "" }
        }
      end
    end
    assert_response :unprocessable_entity
  end

  # Fase 6.13: buscador en vivo por nombre/correo del miembro
  test "el listado filtra por usuario con ?q=" do
    Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    Suscripcion.create!(user: users(:two), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    sign_in_as users(:admin)

    get admin_suscripciones_path(q: users(:one).nombre)

    assert_response :success
    assert_match users(:one).email_address, response.body
    assert_no_match users(:two).email_address, response.body
  end

  test "el link al miembro rompe el turbo_frame del buscador" do
    suscripcion = Suscripcion.create!(user: users(:one), plan: planes(:personalizado),
                                      estado: "activa", fecha_inicio: Date.current)
    sign_in_as users(:admin)

    get admin_suscripciones_path

    assert_select "a[href=?][data-turbo-frame=?]", admin_user_path(suscripcion.user), "_top"
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
