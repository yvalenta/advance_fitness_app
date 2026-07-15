require "rails_helper"

RSpec.describe "Admin::Suscripciones", type: :request do
  it "un miembro no accede a suscripciones" do
    sign_in_as users(:one)
    get admin_suscripciones_path
    expect(response).to redirect_to(root_path)
  end

  it "un entrenador tampoco registra suscripciones (solo admin)" do
    sign_in_as users(:entrenador)

    expect {
      post admin_suscripciones_path, params: {
        suscripcion: { user_id: users(:one).id, fecha_inicio: Date.current }, medicion: { peso_kg: 70 }
      }
    }.not_to change(Suscripcion, :count)
    expect(response).to redirect_to(root_path)
  end

  it "el alta crea la suscripción, la medición y encola la generación con IA" do
    sign_in_as users(:admin)

    expect {
      post admin_suscripciones_path, params: {
        suscripcion: { user_id: users(:one).id, fecha_inicio: Date.current },
        medicion: { peso_kg: 72.5, cintura_cm: 82, pliegue_abdominal_mm: 14 }
      }
    }.to change(Suscripcion, :count).by(1)
      .and change(PlanPersonalizado, :count).by(1)
      .and change(Medicion, :count).by(1)

    suscripcion = Suscripcion.last
    expect(suscripcion.plan).to eq(planes(:personalizado))
    expect(suscripcion.activa?).to be_truthy

    medicion = users(:one).ultima_medicion
    expect(medicion.peso_kg.to_f).to eq(72.5)
    expect(medicion.tomada_por).to eq(users(:admin))

    plan = users(:one).planes_personalizados.last
    expect(plan.generando?).to be_truthy
    expect(GenerarPlanJob).to have_been_enqueued.with(plan.id)
  end

  # Fase 5.11: la membresía va incluida con la suscripción
  it "el alta reactiva la membresía vencida del miembro" do
    sign_in_as users(:admin)

    post admin_suscripciones_path, params: {
      suscripcion: { user_id: users(:two).id, fecha_inicio: Date.current },
      medicion: { peso_kg: 68 }
    }

    membresia = users(:two).membresia.reload
    expect(membresia.activa?).to be_truthy
    expect(membresia.fecha_vencimiento).to eq(Date.current + Membresia.duracion)
  end

  it "el alta crea la membresía si el miembro no tiene (incluida, sin pago)" do
    users(:entrenador).update!(rol: "miembro") # un user sin membresía
    sign_in_as users(:admin)

    expect {
      expect {
        post admin_suscripciones_path, params: {
          suscripcion: { user_id: users(:entrenador).id, fecha_inicio: Date.current },
          medicion: { peso_kg: 80 }
        }
      }.not_to change(Pago, :count)
    }.to change(Membresia, :count).by(1)
    expect(users(:entrenador).membresia.activa?).to be_truthy
  end

  # Fase 5.16: reintentar el alta el mismo día (p. ej. tras un fallo previo)
  # no debe chocar con el índice único user_id+fecha de mediciones.
  it "si el miembro ya tiene medición hoy, el alta la corrige en vez de fallar" do
    users(:one).mediciones.create!(fecha: Date.current, peso_kg: 70, tomada_por: users(:admin))
    sign_in_as users(:admin)

    expect {
      expect {
        post admin_suscripciones_path, params: {
          suscripcion: { user_id: users(:one).id, fecha_inicio: Date.current },
          medicion: { peso_kg: 73.5 }
        }
      }.not_to change(Medicion, :count)
    }.to change(Suscripcion, :count).by(1).and change(PlanPersonalizado, :count).by(1)

    expect(response).to have_http_status(:redirect)
    expect(users(:one).suscripciones.last.activa?).to be_truthy
    expect(users(:one).ultima_medicion.peso_kg.to_f).to eq(73.5)
    expect(users(:one).membresia.activa?).to be_truthy # la regla de negocio sigue aplicando
  end

  it "sin peso en la medición no crea la suscripción ni encola" do
    sign_in_as users(:admin)

    expect {
      expect {
        post admin_suscripciones_path, params: {
          suscripcion: { user_id: users(:one).id, fecha_inicio: Date.current }, medicion: { peso_kg: "" }
        }
      }.not_to have_enqueued_job(GenerarPlanJob)
    }.not_to change { [ Suscripcion.count, Medicion.count, PlanPersonalizado.count ] }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  # Fase 6.13: buscador en vivo por nombre/correo del miembro
  it "el listado filtra por usuario con ?q=" do
    Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    Suscripcion.create!(user: users(:two), plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    sign_in_as users(:admin)

    get admin_suscripciones_path(q: users(:one).nombre)

    expect(response).to have_http_status(:success)
    expect(response.body).to include(users(:one).email_address)
    expect(response.body).not_to include(users(:two).email_address)
  end

  it "el link al miembro rompe el turbo_frame del buscador" do
    suscripcion = Suscripcion.create!(user: users(:one), plan: planes(:personalizado),
                                      estado: "activa", fecha_inicio: Date.current)
    sign_in_as users(:admin)

    get admin_suscripciones_path

    assert_select "a[href=?][data-turbo-frame=?]", admin_user_path(suscripcion.user), "_top"
  end

  it "el badge 'Incluida con membresía' rompe el turbo_frame del buscador" do
    suscripcion = Suscripcion.create!(user: users(:one), plan: planes(:personalizado), estado: "activa",
                                      fecha_inicio: Date.current, membresia: membresias(:vencida_two))
    sign_in_as users(:admin)

    get admin_suscripciones_path

    assert_select "a[href=?][data-turbo-frame=?]", edit_admin_membresia_path(suscripcion.membresia), "_top"
  end

  it "cancelar deja al miembro sin premium" do
    sign_in_as users(:admin)
    suscripcion = Suscripcion.create!(user: users(:one), plan: planes(:personalizado),
                                      estado: "activa", fecha_inicio: Date.current)

    patch admin_suscripcion_path(suscripcion)

    expect(suscripcion.reload.estado).to eq("cancelada")
    expect(users(:one).premium?).to be_falsey
  end

  # Fase 12.1: el nivel de análisis se cambia desde la ficha del miembro (ya
  # no una columna en este listado) y responde turbo_stream, sin recargar.
  it "cambiar el nivel de análisis responde turbo_stream sin recargar" do
    sign_in_as users(:admin)
    suscripcion = Suscripcion.create!(user: users(:one), plan: planes(:personalizado),
                                      estado: "activa", fecha_inicio: Date.current)

    patch admin_suscripcion_path(suscripcion), params: { analisis_tier: "semanal" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:success)
    expect(response.media_type).to match("turbo-stream")
    assert_select "turbo-stream[action=replace][target=?]", "panel_analisis_#{users(:one).id}"
    expect(suscripcion.reload.analisis_tier).to eq("semanal")
  end
end
