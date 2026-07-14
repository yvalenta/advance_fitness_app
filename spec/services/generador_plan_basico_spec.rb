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
    expect(ejercicio.keys.sort).to eq(%w[descanso_seg nombre repeticiones series])
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

  it "la semana rota ejercicios entre repeticiones del mismo enfoque" do
    2.times { |i| PlantillaEjercicio.find_or_create_by!(musculo: "pecho", nombre: "Press extra #{i}") { |p| p.repeticiones = "8" } }
    rutina = GeneradorPlanBasico.para(users(:one), objetivo: objetivo("superavit"))

    lunes = rutina["dias"][0]["ejercicios"].map { |e| e["nombre"] }
    jueves = rutina["dias"][3]["ejercicios"].map { |e| e["nombre"] }
    expect(lunes).not_to eq(jueves)
  end
end
