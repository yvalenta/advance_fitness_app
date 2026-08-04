require "rails_helper"

RSpec.describe GeneradorPlanBasico, type: :model do
  before do
    %w[pecho espalda pierna hombro biceps triceps core gluteo].each do |musculo|
      PlantillaEjercicio.find_or_create_by!(musculo: musculo, nombre: "Ej #{musculo}") do |p|
        p.series = 3
        p.repeticiones = "10"
        p.descanso_seg = 60
      end
    end
  end

  def objetivo(tipo) = ObjetivoNutricional.new(tipo: tipo)

  it "superavit arma 6 días Push/Pull/Legs con ejercicios" do
    rutina = GeneradorPlanBasico.para(users(:one), objetivo: objetivo("superavit"))

    expect(rutina["dias"].map { |d| d["dia"] }).to eq(%w[lunes martes miercoles jueves viernes sabado])
    expect(rutina["dias"][0]["enfoque"]).to match(/Empuje/)
    expect(rutina["dias"][1]["enfoque"]).to match(/Jalón/)
    expect(rutina["dias"].all? { |d| d["ejercicios"].any? }).to be_truthy
  end

  it "deficit arma 6 días full-body alterno" do
    rutina = GeneradorPlanBasico.para(users(:one), objetivo: objetivo("deficit"))

    expect(rutina["dias"].size).to eq(6)
    expect(rutina["dias"].all? { |d| d["enfoque"].include?("Cuerpo completo") }).to be_truthy
  end

  it "sin objetivo usa torso/pierna y la forma de ejercicio es válida" do
    rutina = GeneradorPlanBasico.para(User.new)

    expect(rutina["dias"].size).to eq(6)
    ejercicio = rutina["dias"].first["ejercicios"].first
    # Fase 14.6: + uid — la identidad estable por entrada para el seguimiento
    expect(ejercicio.keys.sort).to eq(%w[descanso_seg nombre repeticiones series uid])
    expect(ejercicio["nombre"].present?).to be_truthy
  end

  # Fase 6.4: la plantilla enlazada al catálogo propaga su ejercicio_id
  it "incluye ejercicio_id cuando la plantilla está enlazada al catálogo" do
    ejercicio = Ejercicio.create!(dataset_id: "0025", nombre: "Press de banca", nombre_en: "barbell bench press",
                                  musculo: "pecho", categoria: "chest")
    PlantillaEjercicio.find_by(musculo: "pecho", nombre: "Ej pecho").update!(ejercicio: ejercicio)

    rutina = GeneradorPlanBasico.para(users(:one), objetivo: objetivo("superavit"))

    con_id = rutina["dias"].flat_map { |d| d["ejercicios"] }.select { |e| e["ejercicio_id"] }
    expect(con_id.any?).to be_truthy
    expect(con_id.first["ejercicio_id"]).to eq(ejercicio.id)
  end

  # Fase 14.6: identidad estable por ENTRADA — única aunque la misma plantilla
  # se repita en la semana.
  it "cada ejercicio del plan por reglas nace con uid único" do
    rutina = GeneradorPlanBasico.para(users(:one), objetivo: objetivo("superavit"))
    uids = rutina["dias"].flat_map { |d| d["ejercicios"] }.map { |e| e["uid"] }

    expect(uids.any?).to be_truthy
    expect(uids).to all(match(/\A[a-zA-Z0-9]{10}\z/))
    expect(uids.uniq.size).to eq(uids.size)
  end

  # Fase 14.8: el plan por reglas nace como mesociclo v2 con la progresión
  # lineal determinista (la misma progresión por defecto del validador).
  it "el plan por reglas es un mesociclo v2 de 4 semanas con descarga final" do
    rutina = GeneradorPlanBasico.para(users(:one), objetivo: objetivo("superavit"))

    expect(rutina["version"]).to eq(2)
    expect(rutina["mesociclo"]).to include("semanas_total" => 4, "progresion" => "lineal")
    expect(rutina["semanas"].map { |s| s["numero"] }).to eq([ 1, 2, 3, 4 ])
    expect(rutina["semanas"].map { |s| s["ajuste"]["peso_factor"] }).to eq([ 1.0, 1.05, 1.1, 0.85 ])
    ultima = rutina["semanas"].last
    expect(ultima["descarga"]).to be(true)
    expect(ultima["ajuste"]["peso_factor"]).to be <= 0.9
    # Semanas SIN materializar: los días viven una sola vez en la base
    expect(rutina["semanas"].map { |s| s["dias"] }).to all(be_nil)
  end

  it "la semana rota ejercicios entre repeticiones del mismo enfoque" do
    2.times { |i| PlantillaEjercicio.find_or_create_by!(musculo: "pecho", nombre: "Press extra #{i}") { |p| p.repeticiones = "8" } }
    rutina = GeneradorPlanBasico.para(users(:one), objetivo: objetivo("superavit"))

    lunes = rutina["dias"][0]["ejercicios"].map { |e| e["nombre"] }
    jueves = rutina["dias"][3]["ejercicios"].map { |e| e["nombre"] }
    expect(lunes).not_to eq(jueves)
  end
end
