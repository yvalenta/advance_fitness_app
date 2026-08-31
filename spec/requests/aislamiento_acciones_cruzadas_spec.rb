require "rails_helper"

# Igual que en seeds_spec: matcher negado componible para encadenar con .and
RSpec::Matchers.define_negated_matcher :not_change, :change

# La clase de spec que faltaba (tarea 2026-08-31): el aislamiento cross-tenant
# solo se probaba a nivel de Scope.resolve — nadie disparaba la ACCIÓN
# cruzada. Estos ejemplos son el staff del gimnasio A apuntando por ID a un
# miembro (o a la plata) del gimnasio B: todo debe morir en 404 indistinguible
# (el ID ajeno "no existe"), sin escribir nada, sin encolar jobs y sin filtrar
# ni el estado de membresía en un flash.
#
# El 404 sale de policy_scope(...).find en el controller; la política además
# revisa el record (defensa en profundidad) — si mañana un controller
# descuidado vuelve al find crudo, los specs de policy lo cazan igual.
RSpec.describe "Acciones cruzadas entre tenants (staff de A contra datos de B)", type: :request do
  let(:tenant_mp) { tenants(:megaplex) }

  let(:admin_mp) do
    User.create!(email_address: "admin-mp@x.com", password: "clave1234",
                 rol: "admin", tenant: tenant_mp, nombre: "Admin MP")
  end
  # El miembro de B con TODO lo que un check-in o una medición necesitarían:
  # membresía activa incluida — si el hueco existiera, la acción cruzada
  # completaría feliz.
  let(:miembro_mp) do
    User.create!(email_address: "fugado@megaplex.local", password: "clave1234",
                 rol: "miembro", tenant: tenant_mp, nombre: "Fugado Megaplex",
                 fecha_nacimiento: "1990-01-01", sexo: "M",
                 talla_cm: 175, nivel_actividad: 1.55)
  end
  let(:membresia_mp) do
    Membresia.create!(user: miembro_mp, estado: "activa",
                      fecha_inicio: Date.current,
                      fecha_vencimiento: Date.current + 30)
  end

  # El staff de A opera desde el subdominio de A, como en producción.
  before do
    host! "advance-fitness.example.com"
    sign_in_as users(:admin)
  end

  describe "mediciones (dato de salud)" do
    it "GET del historial de un miembro de B → 404" do
      miembro_mp.mediciones.create!(fecha: Date.current, peso_kg: 90)

      get admin_user_mediciones_path(miembro_mp)

      expect(response).to have_http_status(:not_found)
    end

    it "POST de una medición sobre un miembro de B → 404, sin escribir y sin encolar GenerarPlanJob" do
      # Hasta con un plan IA aprobado de B esperando: el reencole tampoco sale.
      PlanPersonalizado.create!(user: miembro_mp, generado_por: "ia", estado: "aprobado",
                                aprobado_por: admin_mp, rutina: { "dias" => [] },
                                plan_nutricional: { "kcal_diarias" => 0, "comidas" => [] })

      expect {
        expect {
          post admin_user_mediciones_path(miembro_mp),
               params: { medicion: { peso_kg: 74 }, actualizar_plan: "1" }
        }.not_to change(Medicion, :count)
      }.not_to have_enqueued_job(GenerarPlanJob)

      expect(response).to have_http_status(:not_found)
    end

    it "control positivo: el mismo staff sí ve el historial de su propio miembro" do
      get admin_user_mediciones_path(users(:one))
      expect(response).to have_http_status(:success)
    end
  end

  describe "check-ins" do
    it "la búsqueda del mostrador no enumera nombre+email de miembros de B" do
      miembro_mp # existe y su email calza con la búsqueda

      get admin_checkins_path(q: "Fugado")

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Fugado Megaplex")
      expect(response.body).not_to include("fugado@megaplex.local")
    end

    it "control positivo: la misma búsqueda sí encuentra al miembro propio" do
      get admin_checkins_path(q: "Uno")
      expect(response.body).to include("Usuario Uno")
    end

    it "POST de check-in sobre un miembro de B → 404, sin Acceso, sin puntos y sin filtrar su membresía" do
      membresia_mp # activa: si el hueco existiera, el check-in completaría

      expect {
        expect {
          post admin_checkins_path, params: { user_id: miembro_mp.id }
        }.not_to change(Acceso, :count)
      }.not_to have_enqueued_job(OtorgarPuntosJob)

      expect(response).to have_http_status(:not_found)
      # El flash de antes ("tiene la membresía X") era la fuga de estado.
      expect(flash[:alert]).to be_nil
      expect(flash[:notice]).to be_nil
    end
  end

  # Los sitios extra que cayeron con el mismo grep (find crudo + policy que
  # solo miraba el rol): ficha de usuario, membresías, renovación, pagos y
  # suscripciones — la plata de B tampoco se toca desde A.
  describe "sitios extra del grep" do
    it "ficha de un miembro de B: GET → 404 y PATCH → 404 sin renombrar" do
      get admin_user_path(miembro_mp)
      expect(response).to have_http_status(:not_found)

      patch admin_user_path(miembro_mp), params: { user: { nombre: "Pirateado" } }
      expect(response).to have_http_status(:not_found)
      expect(miembro_mp.reload.nombre).to eq("Fugado Megaplex")
    end

    it "membresía de B: edit y update → 404, el estado no se mueve" do
      get edit_admin_membresia_path(membresia_mp)
      expect(response).to have_http_status(:not_found)

      patch admin_membresia_path(membresia_mp),
            params: { membresia: { user_id: miembro_mp.id, fecha_inicio: Date.current, estado: "suspendida" } }
      expect(response).to have_http_status(:not_found)
      expect(membresia_mp.reload.estado).to eq("activa")
    end

    it "alta de membresía CON user_id de un miembro de B → la policy la niega y no nace ni membresía ni pago" do
      miembro_sin = User.create!(email_address: "sin-membresia@megaplex.local", password: "clave1234",
                                 rol: "miembro", tenant: tenant_mp, nombre: "Sin Membresía MP")

      expect {
        post admin_membresias_path,
             params: { membresia: { user_id: miembro_sin.id, fecha_inicio: Date.current,
                                    estado: "activa", monto: 80_000, metodo: "efectivo" } }
      }.to not_change(Membresia, :count).and not_change(Pago, :count)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/no tienes permiso/i)
    end

    it "renovación de una membresía de B → 404 y no se cobra nada" do
      membresia_mp

      expect {
        post admin_membresia_renovacion_path(membresia_mp), params: { monto: 80_000, metodo: "efectivo" }
      }.not_to change(Pago, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "pago de B: corregir → 404 con el monto intacto; anular → 404 y sigue vigente" do
      pago_mp = membresia_mp.pagos.create!(monto: 80_000, metodo: "efectivo",
                                           registrado_por: admin_mp, fecha_pago: Date.current,
                                           periodo_inicio: Date.current, periodo_fin: Date.current + 30)

      patch admin_pago_path(pago_mp), params: { pago: { monto: 1 } }
      expect(response).to have_http_status(:not_found)
      expect(pago_mp.reload.monto.to_i).to eq(80_000)

      delete admin_pago_path(pago_mp)
      expect(response).to have_http_status(:not_found)
      expect(pago_mp.reload.anulado?).to be_falsey
    end

    it "suscripción de B: cancelarla o cambiarle el tier → 404 y sigue activa" do
      susc_mp = Suscripcion.create!(user: miembro_mp, plan: planes(:free), estado: "activa",
                                    fecha_inicio: Date.current)

      patch admin_suscripcion_path(susc_mp)
      expect(response).to have_http_status(:not_found)
      expect(susc_mp.reload.estado).to eq("activa")
    end
  end

  # Segunda tanda del grep (tarea 2026-08-31): la familia del editor de
  # planes. El staff de A apuntando por ID al plan de un miembro de B podía
  # abrir el editor, pisar la rutina JSON entera, publicar y encolar
  # GenerarPlanJob sobre datos ajenos — la policy solo miraba el rol del
  # viewer. Ahora TODO entra por policy_scope: id ajeno = 404 indistinguible.
  describe "editor de planes (staff de A contra el plan de un miembro de B)" do
    let(:rutina_b) do
      { "dias" => [ { "dia" => "lunes", "enfoque" => "pecho",
                      "ejercicios" => [ { "nombre" => "Press banca", "series" => 4, "repeticiones" => "8-10" } ] } ] }
    end
    let(:nutricion_b) do
      { "kcal_diarias" => 450,
        "comidas" => [ { "nombre" => "Desayuno", "descripcion" => "Huevos con arepa", "kcal" => 450 } ] }
    end
    let(:plan_mp) do
      PlanPersonalizado.create!(user: miembro_mp, generado_por: "ia", estado: "borrador",
                                rutina: rutina_b, plan_nutricional: nutricion_b)
    end

    it "GET del editor → 404" do
      get plan_personalizado_path(plan_mp)
      expect(response).to have_http_status(:not_found)
    end

    it "PATCH del JSON crudo → 404 y la rutina de B queda INTACTA" do
      patch plan_personalizado_path(plan_mp), params: { rutina: { "dias" => [] }.to_json }

      expect(response).to have_http_status(:not_found)
      expect(plan_mp.reload.rutina).to eq(rutina_b)
      expect(plan_mp.plan_nutricional).to eq(nutricion_b)
    end

    it "POST publicar → 404 y el plan sigue en borrador (B nunca lo ve)" do
      post publicar_plan_personalizado_path(plan_mp)
      expect(response).to have_http_status(:not_found)
      expect(plan_mp.reload.estado).to eq("borrador")
    end

    it "POST regenerar → 404, sin GenerarPlanJob y sin tocar el estado" do
      expect {
        post regenerar_plan_personalizado_path(plan_mp)
      }.not_to have_enqueued_job(GenerarPlanJob)

      expect(response).to have_http_status(:not_found)
      expect(plan_mp.reload.estado).to eq("borrador")
    end

    it "los autosaves hermanos (comida, día, ejercicio, semana) → 404 sin escribir" do
      patch plan_personalizado_comida_path(plan_mp, 0), as: :json, params: { comida: { kcal: "1" } }
      expect(response).to have_http_status(:not_found)

      patch plan_personalizado_dia_path(plan_mp, 0), as: :json, params: { dia: { enfoque: "pirateado" } }
      expect(response).to have_http_status(:not_found)

      patch plan_personalizado_dia_ejercicio_path(plan_mp, 0, 0), as: :json, params: { ejercicio: { series: "9" } }
      expect(response).to have_http_status(:not_found)

      post plan_personalizado_dia_ejercicios_path(plan_mp, 0),
           params: { ejercicio: { nombre: "Colado" } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:not_found)

      get plan_personalizado_semana_path(plan_mp, 1)
      expect(response).to have_http_status(:not_found)

      plan_mp.reload
      expect(plan_mp.rutina).to eq(rutina_b)
      expect(plan_mp.plan_nutricional).to eq(nutricion_b)
    end

    # El flujo legítimo del staff sobre SU miembro no se rompe: regenerar
    # encola y publicar aprueba — el 404 es solo para el gimnasio vecino.
    it "control positivo: el staff sí regenera y publica el plan de su propio miembro" do
      plan_propio = PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "borrador",
                                              rutina: rutina_b, plan_nutricional: nutricion_b)

      expect {
        post regenerar_plan_personalizado_path(plan_propio)
      }.to have_enqueued_job(GenerarPlanJob).with(plan_propio.id)
      expect(plan_propio.reload.generando?).to be true

      plan_propio.update!(estado: "borrador")
      post publicar_plan_personalizado_path(plan_propio)
      expect(response).to redirect_to(plan_personalizado_path(plan_propio))
      expect(plan_propio.reload.estado).to eq("aprobado")
    end

    it "la cola de borradores no lista al miembro de B (y sí al propio)" do
      plan_mp # pendiente de B, esperando colarse
      PlanPersonalizado.create!(user: users(:one), generado_por: "ia", estado: "borrador",
                                rutina: rutina_b, plan_nutricional: nutricion_b)

      get entrenador_borradores_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Usuario Uno")          # control positivo
      expect(response.body).not_to include("Fugado Megaplex")  # ni el nombre de B…
      expect(response.body).not_to include(plan_personalizado_path(plan_mp)) # …ni el enlace a su editor
    end
  end

  describe "análisis de entrenamiento (staff de A contra un registro de B)" do
    it "POST analizar → 404, sin FeedbackIa y sin encolar el job" do
      registro_mp = RegistroEntrenamiento.create!(user: miembro_mp, fecha: Date.current)

      expect {
        expect {
          post analizar_entrenamiento_path, params: { registro_entrenamiento_id: registro_mp.id }
        }.not_to change(FeedbackIa, :count)
      }.not_to have_enqueued_job(AnalizarEntrenamientoJob)

      expect(response).to have_http_status(:not_found)
    end

    it "control positivo: el registro del miembro propio sí se encuentra (aunque falten datos)" do
      registro = RegistroEntrenamiento.create!(user: users(:one), fecha: Date.current)

      post analizar_entrenamiento_path, params: { registro_entrenamiento_id: registro.id }

      # No es 404: el scope lo encontró y la policy lo autorizó; lo que falta
      # son las semanas mínimas de datos (redirige a la ficha con el aviso).
      expect(response).to redirect_to(admin_user_path(users(:one)))
    end
  end
end
