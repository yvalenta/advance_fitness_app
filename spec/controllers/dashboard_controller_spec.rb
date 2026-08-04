require "rails_helper"

# Dashboard "Hoy" (Fase 14.5): qué toca entrenar, racha, calorías, membresía
# y el acceso al explorador de ejercicios. El número de queries es constante
# (todo lo del día se deriva en Ruby de los jsonb) — el último spec lo fija.
RSpec.describe "Dashboard", type: :request do
  let(:miembro) { users(:one) }

  # Nombre del día de HOY en la rutina (p. ej. "miercoles") y otro día
  # cualquiera distinto, para armar planes con/sin sesión hoy.
  let(:dia_hoy_nombre) { PlanPersonalizado::DIAS_OFFSET.key(Date.current.cwday - 1) }
  let(:otro_dia_nombre) { (PlanPersonalizado::DIAS_OFFSET.keys - [ dia_hoy_nombre ]).first }

  def crear_plan_aprobado(dias:)
    PlanPersonalizado.create!(user: miembro, generado_por: "reglas", estado: "aprobado",
                              rutina: { "dias" => dias }, plan_nutricional: {})
  end

  def dia_con_ejercicios(nombre, enfoque: "Pecho y tríceps")
    { "dia" => nombre, "enfoque" => enfoque,
      "ejercicios" => [ { "nombre" => "Press banca", "uid" => "aaaaaaaaaa" },
                        { "nombre" => "Fondos", "uid" => "bbbbbbbbbb" },
                        { "nombre" => "Aperturas", "uid" => "cccccccccc" } ] }
  end

  it "redirects to login when unauthenticated" do
    get root_url
    expect(response).to redirect_to(new_session_url)
  end

  it "muestra el saludo, la racha apagada y el acceso al explorador (sin plan → CTA)" do
    sign_in_as miembro

    get root_url

    expect(response).to have_http_status(:success)
    # El saludo usa solo el primer nombre del miembro
    assert_select "h1", text: /#{miembro.nombre.split.first}/
    # Sin plan aprobado: CTA hacia Mi plan
    expect(response.body).to include("Aún sin plan")
    assert_select "a[href=?]", mi_plan_path, text: "Armar mi plan"
    # Racha renderizada desde un PerfilJuego sin persistir (defaults en 0)
    expect(response.body).to include("Racha")
    expect(response.body).to include("Entrena hoy y enciéndela")
    # Explorador del catálogo (Fase 14.5)
    assert_select "a[href=?]", ejercicios_path
    expect(response.body).to include("Explorar")
    # Fase 5.14: copy sin menciones a "IA" de cara al miembro
    expect(response.body).not_to match(/\bIA\b/)
  end

  it "solo mirar el dashboard NO siembra perfiles de juego (find_or_initialize)" do
    sign_in_as miembro

    expect { get root_url }.not_to change(PerfilJuego, :count)
  end

  it "muestra la racha del PerfilJuego cuando existe" do
    PerfilJuego.create!(user: miembro, racha_actual: 5, racha_mejor: 12)
    sign_in_as miembro

    get root_url

    expect(response.body).to match(/5\s*<[^>]+>días/)
    expect(response.body).to include("Mejor racha: 12 días")
  end

  it "con plan y sesión hoy muestra el enfoque, el conteo y el avance en cero" do
    crear_plan_aprobado(dias: [ dia_con_ejercicios(dia_hoy_nombre) ])
    sign_in_as miembro

    get root_url

    expect(response.body).to include("Hoy te toca")
    expect(response.body).to include("Pecho y tríceps")
    expect(response.body).to include("3 ejercicios")
    expect(response.body).to include("0 de 3 hechos")
    # Cableado 14.3: el CTA principal lleva al modo sesión; Mi plan queda
    # como acción secundaria.
    assert_select "a[href=?]", sesion_path, text: /Empezar entrenamiento/
    assert_select "a[href=?]", mi_plan_path, text: "Ver mi plan"
  end

  it "el avance del día lee un registro v1 (claves numéricas)" do
    crear_plan_aprobado(dias: [ dia_con_ejercicios(dia_hoy_nombre) ])
    miembro.registros_entrenamiento.create!(
      fecha: Date.current,
      ejercicios: { "0" => { "hecho" => true, "nombre" => "Press banca" },
                    "1" => { "hecho" => false, "nombre" => "Fondos" },
                    "novedad" => "todo bien" }
    )
    sign_in_as miembro

    get root_url

    expect(response.body).to include("1 de 3 hechos")
  end

  it "el avance del día lee un registro v2 (items por uid)" do
    crear_plan_aprobado(dias: [ dia_con_ejercicios(dia_hoy_nombre) ])
    miembro.registros_entrenamiento.create!(
      fecha: Date.current,
      ejercicios: { "version" => 2,
                    "items" => { "aaaaaaaaaa" => { "hecho" => true, "nombre" => "Press banca" },
                                 "bbbbbbbbbb" => { "hecho" => true, "nombre" => "Fondos" },
                                 "cccccccccc" => { "hecho" => false, "nombre" => "Aperturas" } } }
    )
    sign_in_as miembro

    get root_url

    expect(response.body).to include("2 de 3 hechos")
  end

  it "con plan pero sin sesión hoy muestra descanso" do
    crear_plan_aprobado(dias: [ dia_con_ejercicios(otro_dia_nombre) ])
    sign_in_as miembro

    get root_url

    expect(response.body).to include("Descanso")
    assert_select "a[href=?]", mi_plan_path, text: "Ver mi plan"
  end

  # Red anti-N+1: el dashboard hace el MISMO número de queries con el panel
  # lleno (plan de varios días, registro del día, perfil de juego, objetivo)
  # que vacío — todo lo del día se resuelve en Ruby sobre los jsonb.
  it "hace un número constante de queries con y sin datos" do
    sign_in_as miembro
    get root_url # calienta prepared statements / schema cache
    sin_datos = contar_queries { get root_url }

    crear_plan_aprobado(dias: PlanPersonalizado::DIAS_OFFSET.keys.first(5).map { |dia| dia_con_ejercicios(dia) })
    miembro.registros_entrenamiento.create!(
      fecha: Date.current,
      ejercicios: { "version" => 2, "items" => { "aaaaaaaaaa" => { "hecho" => true } } }
    )
    PerfilJuego.create!(user: miembro, racha_actual: 3, racha_mejor: 9)
    con_datos = contar_queries { get root_url }

    expect(con_datos).to eq(sin_datos)
  end

  def contar_queries
    contador = 0
    contar = lambda do |_nombre, _inicio, _fin, _id, payload|
      contador += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION", "CACHE" ])
    end
    ActiveSupport::Notifications.subscribed(contar, "sql.active_record") { yield }
    contador
  end
end
