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
end
