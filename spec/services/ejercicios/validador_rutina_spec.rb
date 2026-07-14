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
end
