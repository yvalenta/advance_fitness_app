require "rails_helper"

# Modo sesión (Fase 14.3): pantalla inmersiva del entrenamiento del día.
RSpec.describe "Sesiones", type: :request do
  let(:lunes) { Date.current.beginning_of_week }
  let(:rutina) do
    { "dias" => [
      { "dia" => "lunes", "enfoque" => "Empuje: pecho y tríceps",
        "ejercicios" => [
          { "uid" => "abc123", "nombre" => "Press banca", "series" => 3,
            "repeticiones" => "12-15", "descanso_seg" => 90,
            "peso_sugerido_kg" => 60, "nota_tecnica" => "Escápulas retraídas" },
          { "nombre" => "Fondos", "series" => 4, "repeticiones" => "10" }
        ] }
    ] }
  end

  def crear_plan!(user, rutina:)
    PlanPersonalizado.create!(user: user, generado_por: "reglas", estado: "aprobado",
                              rutina: rutina, plan_nutricional: {})
  end

  it "muestra la sesión del día con avance, chips de series y nota técnica" do
    crear_plan!(users(:one), rutina: rutina)
    sign_in_as users(:one)

    get sesion_path(lunes.iso8601)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Ejercicio 1 de 2")
    expect(response.body).to include("Press banca")
    expect(response.body).to include("Serie 3")                 # chips por serie
    expect(response.body).to include("Escápulas retraídas")     # nota técnica
    expect(response.body).to include("Marcar día como hecho")
    expect(response.body).to include(registros_entrenamiento_path) # endpoint existente
  end

  # Wake Lock (Fase 19d): la sección arranca con el controller y el value
  # que refleja la preferencia del miembro — apagable en Ajustes.
  it "pasa la preferencia de pantalla activa al Stimulus de wake lock" do
    crear_plan!(users(:one), rutina: rutina)
    sign_in_as users(:one)

    get sesion_path(lunes.iso8601)
    expect(response.body).to include('data-controller="sesion wake-lock"')
    expect(response.body).to include('data-wake-lock-activo-value="true"')

    users(:one).update!(wake_lock_activo: false)
    get sesion_path(lunes.iso8601)
    expect(response.body).to include('data-wake-lock-activo-value="false"')
  end

  it "serializa uid/series/descanso_seg en el JSON que consume el Stimulus" do
    crear_plan!(users(:one), rutina: rutina)
    sign_in_as users(:one)

    get sesion_path(lunes.iso8601)

    expect(response.body).to include('"uid":"abc123"')
    expect(response.body).to include('"series":3')
    expect(response.body).to include('"descanso_seg":90')
    # Rutinas sin uid caen al índice y sin descanso usan 60 s por defecto
    expect(response.body).to include('"uid":"1"')
    expect(response.body).to include('"descanso_seg":60')
  end

  # Fase 20: tipo (timer de trabajo) y grupo_superserie (par sin descanso)
  # en el JSON que arma el Stimulus — la lectura HTML usa el hash crudo.
  it "serializa tipo y grupo_superserie para el Stimulus" do
    rutina_superserie = { "dias" => [
      { "dia" => "lunes", "ejercicios" => [
        { "uid" => "a1", "nombre" => "Press banca", "series" => 3, "repeticiones" => "10", "grupo_superserie" => "A" },
        { "uid" => "b1", "nombre" => "Plancha", "series" => 3, "repeticiones" => "40", "tipo" => "tiempo", "grupo_superserie" => "A" }
      ] }
    ] }
    crear_plan!(users(:one), rutina: rutina_superserie)
    sign_in_as users(:one)

    get sesion_path(lunes.iso8601)

    expect(response.body).to include('"tipo":"reps"')
    expect(response.body).to include('"tipo":"tiempo"')
    expect(response.body.scan('"grupo_superserie":"A"').size).to eq(2)
  end

  it "un ejercicio unilateral muestra las reps por lado, y la superserie su badge" do
    rutina_mixta = { "dias" => [
      { "dia" => "lunes", "ejercicios" => [
        { "uid" => "z1", "nombre" => "Zancadas", "series" => 3, "repeticiones" => "8-10",
          "unilateral" => true, "grupo_superserie" => "B" }
      ] }
    ] }
    crear_plan!(users(:one), rutina: rutina_mixta)
    sign_in_as users(:one)

    get sesion_path(lunes.iso8601)

    expect(response.body).to include("4-5 por lado")
    expect(response.body).to include("Superserie")
  end

  # Fase 18l: la sesión captura las series cuantitativas al tap (premium).
  describe "registro cuantitativo por serie" do
    let(:ejercicio_catalogo) do
      Ejercicio.create!(dataset_id: "sesion-0001", nombre: "Press banca", nombre_en: "Bench press",
                        nombre_normalizado: "press banca", categoria: "fuerza", musculo: "pecho")
    end
    let(:rutina_con_id) do
      { "dias" => [ { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [
        { "uid" => "abc123", "nombre" => "Press banca", "series" => 3, "repeticiones" => "8-10",
          "descanso_seg" => 90, "peso_sugerido_kg" => 60, "ejercicio_id" => ejercicio_catalogo.id } ] } ] }
    end

    def premium!(user)
      Suscripcion.create!(user: user, plan: planes(:personalizado), estado: "activa", fecha_inicio: Date.current)
    end

    it "premium recibe la URL de detalles, el kg sugerido y las series ya registradas" do
      crear_plan!(users(:one), rutina: rutina_con_id)
      premium!(users(:one))
      pasado = users(:one).registros_entrenamiento.create!(fecha: lunes - 7)
      pasado.detalles.create!(ejercicio: ejercicio_catalogo, serie: 1, repeticiones: 8, peso_kg: 62.5)
      hoy = users(:one).registros_entrenamiento.create!(fecha: lunes)
      hoy.detalles.create!(ejercicio: ejercicio_catalogo, serie: 1, repeticiones: 8, peso_kg: 62.5)
      sign_in_as users(:one)

      get sesion_path(lunes.iso8601)

      expect(response.body).to include("data-sesion-detalles-url-value=\"#{detalles_entrenamiento_path}\"")
      # El sugerido que muestra la pantalla, no la vez pasada: la sesión no
      # tiene input de peso (ver el bug de la regla más abajo).
      expect(response.body).to include('"peso_registro_kg":60.0')
      expect(response.body).to include('"series_registradas":1')  # re-visita: el chip amanece marcado
    end

    # Lo que sesion_controller.js lee del <script type="application/json">.
    def datos_de_la_sesion
      JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-sesion-target='datos']").text)
    end

    # Replica registrarSerie() del Stimulus: un POST por chip con las reps
    # del piso del rango y el kg que la sesión le entregó.
    def completar_series!(fecha, ejercicio)
      ejercicio["series"].times do |i|
        post detalles_entrenamiento_path, params: {
          fecha: fecha.iso8601, ejercicio_id: ejercicio["ejercicio_id"], nombre: ejercicio["nombre"],
          serie: i + 1, repeticiones: ejercicio["repeticiones"].to_i,
          peso_kg: ejercicio["peso_registro_kg"], uid: ejercicio["uid"]
        }
      end
    end

    # Bug (septiembre 2026): la sesión prefería el kg de la vez pasada al
    # sugerido, y Progresion::Regla solo sube si se levantó EXACTO el
    # sugerido — tras el primer +2.5 la sesión 2 volvía a registrar el peso
    # viejo y la progresión quedaba congelada para siempre.
    it "tras el incremento de la regla, la sesión siguiente registra el sugerido nuevo y vuelve a progresar" do
      plan = crear_plan!(users(:one), rutina: rutina_con_id)
      premium!(users(:one))
      sign_in_as users(:one)

      get sesion_path((lunes - 7).iso8601)
      completar_series!(lunes - 7, datos_de_la_sesion["ejercicios"].first)
      expect(plan.reload.ejercicios_de(0).first["peso_sugerido_kg"]).to eq(62.5)

      get sesion_path(lunes.iso8601)
      ejercicio = datos_de_la_sesion["ejercicios"].first
      expect(ejercicio["peso_registro_kg"]).to eq(62.5) # lo que muestra "≈62.5 kg"
      completar_series!(lunes, ejercicio)

      hoy = users(:one).registros_entrenamiento.find_by!(fecha: lunes)
      expect(hoy.detalles.pluck(:peso_kg).uniq).to eq([ 62.5 ])
      expect(plan.reload.ejercicios_de(0).first["peso_sugerido_kg"]).to eq(65)
    end

    # Un deload lo decide el staff bajando el sugerido (la regla nunca baja
    # sola): la sesión registra el peso de la descarga, no el de la vez
    # pasada — con max(anterior, sugerido) el deload sería invisible.
    it "si el staff baja el sugerido, registra la descarga y no el peso de la vez pasada" do
      rutina_con_id["dias"].first["ejercicios"].first["peso_sugerido_kg"] = 50
      crear_plan!(users(:one), rutina: rutina_con_id)
      premium!(users(:one))
      pasado = users(:one).registros_entrenamiento.create!(fecha: lunes - 7)
      pasado.detalles.create!(ejercicio: ejercicio_catalogo, serie: 1, repeticiones: 8, peso_kg: 60)
      sign_in_as users(:one)

      get sesion_path(lunes.iso8601)

      expect(datos_de_la_sesion["ejercicios"].first["peso_registro_kg"]).to eq(50)
    end

    it "sin peso sugerido en el plan cae al kg de la vez pasada" do
      rutina_con_id["dias"].first["ejercicios"].first.delete("peso_sugerido_kg")
      crear_plan!(users(:one), rutina: rutina_con_id)
      premium!(users(:one))
      pasado = users(:one).registros_entrenamiento.create!(fecha: lunes - 7)
      pasado.detalles.create!(ejercicio: ejercicio_catalogo, serie: 1, repeticiones: 8, peso_kg: 20)
      sign_in_as users(:one)

      get sesion_path(lunes.iso8601)

      expect(datos_de_la_sesion["ejercicios"].first["peso_registro_kg"]).to eq(20)
    end

    it "free no recibe la URL de detalles (chips solo visuales) y de estreno va el sugerido" do
      crear_plan!(users(:one), rutina: rutina_con_id)
      sign_in_as users(:one)

      get sesion_path(lunes.iso8601)

      expect(response.body).to include('data-sesion-detalles-url-value=""')
      expect(response.body).to include('"series_registradas":0')
    end
  end

  it "sin plan publicado muestra el estado vacío con link a Mi plan" do
    sign_in_as users(:one)

    get sesion_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Aún no tienes un plan")
    expect(response.body).to include(mi_plan_path)
  end

  it "una fecha sin día programado en la rutina es descanso" do
    crear_plan!(users(:one), rutina: rutina) # solo lunes
    sign_in_as users(:one)

    get sesion_path((lunes + 6).iso8601) # domingo

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Hoy toca descanso")
    expect(response.body).to include(mi_plan_path)
  end

  it "cada quien ve su propia sesión: el plan de otro usuario no se filtra" do
    crear_plan!(users(:one), rutina: rutina)
    sign_in_as users(:two) # sin plan propio

    get sesion_path(lunes.iso8601)

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include("Press banca")
    expect(response.body).to include("Aún no tienes un plan")
  end

  it "con version: 2 toma la rutina base (rutina['dias']) igual" do
    crear_plan!(users(:one), rutina: rutina.merge("version" => 2))
    sign_in_as users(:one)

    get sesion_path(lunes.iso8601)

    expect(response.body).to include("Press banca")
  end

  it "una fecha inválida cae al día de hoy sin reventar" do
    sign_in_as users(:one)

    get "/sesion/2026-13-40" # pasa el constraint pero no es fecha ISO válida

    expect(response).to have_http_status(:success)
  end

  it "sin sesión iniciada redirige al login" do
    get sesion_path
    expect(response).to have_http_status(:redirect)
  end

  # Composición ciclo × mesociclo (Fase 14.16): la sesión sirve los números
  # EFECTIVOS — el ajuste de la semana compuesto con el de la fase del ciclo.
  describe "composición con la fase del ciclo" do
    let(:miembra) { users(:one) }

    def consentir_y_registrar_ciclo!(fecha_inicio: Date.current)
      miembra.consentimientos.create!(tipo: "ciclo_menstrual", accion: "otorgado",
                                      version_texto: "ciclo-v1")
      CicloMenstrual.create!(user: miembra, creado_por: miembra, fecha_inicio: fecha_inicio)
    end

    it "en fase menstrual baja peso y series con el clamp compuesto, y muestra el mensaje" do
      crear_plan!(miembra, rutina: rutina)
      consentir_y_registrar_ciclo!(fecha_inicio: lunes) # el lunes cursa fase menstrual
      sign_in_as miembra

      get sesion_path(lunes.iso8601)

      # menstrual: peso ×0.85 (60 → 51.0, a medios kilos) y series 3−1 = 2
      expect(response.body).to include('"peso_sugerido_kg":51.0')
      expect(response.body).to include('"series":2')
      expect(response.body).to include("baja un poco la carga")
    end

    it "sin consentimiento la fase es desconocida: números base y sin mensaje" do
      crear_plan!(miembra, rutina: rutina)
      CicloMenstrual.create!(user: miembra, creado_por: miembra, fecha_inicio: lunes)
      sign_in_as miembra

      get sesion_path(lunes.iso8601)

      expect(response.body).to include('"peso_sugerido_kg":60')
      expect(response.body).to include('"series":3')
      expect(response.body).not_to include("baja un poco la carga")
    end

    it "compone con la semana del mesociclo respetando el piso 0.7 del factor" do
      rutina_v2 = rutina.merge(
        "version" => 2,
        "mesociclo" => { "nombre" => "Meso", "semanas_total" => 1,
                         "inicio" => lunes.iso8601, "progresion" => "lineal" },
        "semanas" => [ { "numero" => 1, "etiqueta" => "Descarga", "descarga" => true,
                         "ajuste" => { "series_delta" => 0, "peso_factor" => 0.8, "reps_delta" => 0 },
                         "dias" => nil } ]
      )
      crear_plan!(miembra, rutina: rutina_v2)
      consentir_y_registrar_ciclo!(fecha_inicio: lunes)
      sign_in_as miembra

      get sesion_path(lunes.iso8601)

      # 0.8 × 0.85 = 0.68 → clamp 0.7 (Rutina::Resolutor::PESO_FACTOR_COMPUESTO)
      # 60 × 0.7 = 42.0
      expect(response.body).to include('"peso_sugerido_kg":42.0')
    end
  end
end
