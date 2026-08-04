require "rails_helper"

RSpec.describe Ejercicios::ValidadorRutina, type: :model do
  before do
    @press = Ejercicio.create!(dataset_id: "0025", nombre: "Press de banca con barra",
                               nombre_en: "barbell bench press", musculo: "pecho", categoria: "chest")
  end

  def rutina_con(ejercicio)
    { "dias" => [ { "dia" => "lunes", "ejercicios" => [ ejercicio ] } ] }
  end

  it "id válido se conserva y el nombre se pisa con el del catálogo" do
    resultado = Ejercicios::ValidadorRutina.corregir!(
      rutina_con({ "ejercicio_id" => @press.id, "nombre" => "press banca (variante IA)", "series" => 4 })
    )

    ejercicio = resultado[:rutina]["dias"][0]["ejercicios"][0]
    expect(ejercicio["ejercicio_id"]).to eq(@press.id)
    expect(ejercicio["nombre"]).to eq("Press de banca con barra")
    expect(resultado[:correcciones]).to eq(1)
  end

  it "id alucinado se rescata por nombre" do
    resultado = Ejercicios::ValidadorRutina.corregir!(
      rutina_con({ "ejercicio_id" => 999_999, "nombre" => "Préss de Banca con Barra" })
    )

    ejercicio = resultado[:rutina]["dias"][0]["ejercicios"][0]
    expect(ejercicio["ejercicio_id"]).to eq(@press.id)
    expect(resultado[:correcciones]).to eq(1)
  end

  it "sin match se elimina el id pero el ejercicio sobrevive" do
    resultado = Ejercicios::ValidadorRutina.corregir!(
      rutina_con({ "ejercicio_id" => 999_999, "nombre" => "Invento total", "series" => 3 })
    )

    ejercicio = resultado[:rutina]["dias"][0]["ejercicios"][0]
    expect(ejercicio["ejercicio_id"]).to be_nil
    expect(ejercicio["nombre"]).to eq("Invento total")
    expect(resultado[:correcciones]).to eq(1)
  end

  it "una rutina correcta pasa sin correcciones" do
    resultado = Ejercicios::ValidadorRutina.corregir!(
      rutina_con({ "ejercicio_id" => @press.id, "nombre" => "Press de banca con barra" })
    )

    expect(resultado[:correcciones]).to eq(0)
  end

  # Fase 14.6: la IA no conoce el uid (no va en su prompt); el validador se lo
  # estrena a toda entrada que llegue sin él — único POR ENTRADA, incluso si el
  # ejercicio se repite.
  it "una rutina de la IA sin uids sale con uids únicos" do
    rutina = { "dias" => [
      { "dia" => "lunes", "ejercicios" => [
        { "ejercicio_id" => @press.id, "nombre" => "Press de banca con barra" },
        { "ejercicio_id" => @press.id, "nombre" => "Press de banca con barra" }
      ] },
      { "dia" => "martes", "ejercicios" => [ { "nombre" => "Invento total" } ] }
    ] }

    resultado = Ejercicios::ValidadorRutina.corregir!(rutina)

    uids = resultado[:rutina]["dias"].flat_map { |d| d["ejercicios"] }.map { |e| e["uid"] }
    expect(uids).to all(match(/\A[a-zA-Z0-9]{10}\z/))
    expect(uids.uniq.size).to eq(3)
  end

  it "asignar uid no cuenta como corrección y un uid ya presente se respeta" do
    resultado = Ejercicios::ValidadorRutina.corregir!(
      rutina_con({ "ejercicio_id" => @press.id, "nombre" => "Press de banca con barra", "uid" => "yaexiste01" })
    )

    expect(resultado[:rutina]["dias"][0]["ejercicios"][0]["uid"]).to eq("yaexiste01")
    expect(resultado[:correcciones]).to eq(0)
  end

  # ── Fase 14.8: mesociclo v2 ──────────────────────────────────────────────

  def semana(numero, ajuste: { "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 }, dias: nil)
    { "numero" => numero, "etiqueta" => "Semana #{numero}", "descarga" => false,
      "ajuste" => ajuste, "dias" => dias }
  end

  it "corrige ejercicio_id y estrena uid también en las semanas materializadas" do
    rutina = {
      "version" => 2,
      "mesociclo" => { "nombre" => "x", "semanas_total" => 2, "inicio" => nil, "progresion" => "lineal" },
      "dias" => [ { "dia" => "lunes", "ejercicios" => [
        { "ejercicio_id" => @press.id, "nombre" => "Press de banca con barra", "uid" => "base000001" }
      ] } ],
      "semanas" => [
        semana(1, dias: [ { "dia" => "lunes", "ejercicios" => [
          { "ejercicio_id" => 999_999, "nombre" => "Préss de Banca con Barra" }
        ] } ]),
        semana(2)
      ]
    }

    resultado = Ejercicios::ValidadorRutina.corregir!(rutina)

    materializado = resultado[:rutina]["semanas"][0]["dias"][0]["ejercicios"][0]
    expect(materializado["ejercicio_id"]).to eq(@press.id)       # rescate por nombre
    expect(materializado["uid"]).to match(/\A[a-zA-Z0-9]{10}\z/) # identidad estable
    expect(resultado[:rutina]["dias"][0]["ejercicios"][0]["uid"]).to eq("base000001")
    expect(resultado[:correcciones]).to eq(1)
  end

  it "clampa los ajustes alucinados y las no-cifras caen a identidad" do
    rutina = {
      "dias" => [],
      "mesociclo" => { "nombre" => "x", "semanas_total" => 4, "inicio" => nil, "progresion" => "lineal" },
      "semanas" => [
        semana(1, ajuste: { "series_delta" => 50, "peso_factor" => 9.0, "reps_delta" => "muchísimas" }),
        semana(2, ajuste: { "series_delta" => -30, "peso_factor" => "no sé", "reps_delta" => 1 }),
        semana(3),
        semana(4, ajuste: { "series_delta" => 0, "peso_factor" => 0.85, "reps_delta" => 0 })
      ]
    }

    resultado = Ejercicios::ValidadorRutina.corregir!(rutina)

    ajustes = resultado[:rutina]["semanas"].map { |s| s["ajuste"] }
    expect(ajustes[0]).to eq({ "series_delta" => 2, "peso_factor" => 1.5, "reps_delta" => 0 })
    expect(ajustes[1]).to eq({ "series_delta" => -2, "peso_factor" => 1.0, "reps_delta" => 1 })
    expect(ajustes[2]).to eq({ "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 })
    expect(ajustes[3]).to eq({ "series_delta" => 0, "peso_factor" => 0.85, "reps_delta" => 0 })
    # 3 saneos en la semana 1 + 2 en la semana 2; las sanas no cuentan
    expect(resultado[:correcciones]).to eq(5)
  end

  it "semanas basura se reconstruyen con la progresión por defecto" do
    [ "otoño-invierno", [ "semana 1", "semana 2" ], {} ].each do |basura|
      resultado = Ejercicios::ValidadorRutina.corregir!({ "version" => 2, "dias" => [], "semanas" => basura })

      semanas = resultado[:rutina]["semanas"]
      expect(semanas.map { |s| s["etiqueta"] }).to eq(%w[Adaptación Acumulación Intensificación Descarga])
      expect(semanas.last["descarga"]).to be(true)
      expect(resultado[:rutina]["mesociclo"]["semanas_total"]).to eq(4)
      expect(resultado[:correcciones]).to eq(1)
    end
  end

  it "semanas_total alucinado se recorta a 1..8 y el no numérico cae al conteo real" do
    resultado = Ejercicios::ValidadorRutina.corregir!(
      { "dias" => [], "semanas" => [ semana(1), semana(2) ],
        "mesociclo" => { "nombre" => "x", "semanas_total" => 99 } }
    )
    expect(resultado[:rutina]["mesociclo"]["semanas_total"]).to eq(8)
    expect(resultado[:correcciones]).to eq(1)

    resultado = Ejercicios::ValidadorRutina.corregir!(
      { "dias" => [], "semanas" => [ semana(1), semana(2) ],
        "mesociclo" => { "nombre" => "x", "semanas_total" => "todo el año" } }
    )
    expect(resultado[:rutina]["mesociclo"]["semanas_total"]).to eq(2)
    expect(resultado[:correcciones]).to eq(1)
  end

  it "una rutina v1 pasa igual que siempre, sin que se le invente mesociclo" do
    resultado = Ejercicios::ValidadorRutina.corregir!(
      rutina_con({ "ejercicio_id" => @press.id, "nombre" => "Press de banca con barra" })
    )

    expect(resultado[:rutina]).not_to have_key("semanas")
    expect(resultado[:rutina]).not_to have_key("mesociclo")
    expect(resultado[:correcciones]).to eq(0)
  end
end
