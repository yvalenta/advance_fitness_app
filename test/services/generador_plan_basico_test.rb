require "test_helper"

class GeneradorPlanBasicoTest < ActiveSupport::TestCase
  setup do
    %w[pecho espalda pierna hombro biceps triceps core gluteo].each do |musculo|
      PlantillaEjercicio.find_or_create_by!(musculo: musculo, nombre: "Ej #{musculo}") do |p|
        p.series = 3
        p.repeticiones = "10"
        p.descanso_seg = 60
      end
    end
  end

  def objetivo(tipo) = ObjetivoNutricional.new(tipo: tipo)

  test "superavit arma 6 días Push/Pull/Legs con ejercicios" do
    rutina = GeneradorPlanBasico.para(users(:one), objetivo: objetivo("superavit"))

    assert_equal %w[lunes martes miercoles jueves viernes sabado], rutina["dias"].map { |d| d["dia"] }
    assert_match(/Empuje/, rutina["dias"][0]["enfoque"])
    assert_match(/Jalón/, rutina["dias"][1]["enfoque"])
    assert rutina["dias"].all? { |d| d["ejercicios"].any? }
  end

  test "deficit arma 6 días full-body alterno" do
    rutina = GeneradorPlanBasico.para(users(:one), objetivo: objetivo("deficit"))

    assert_equal 6, rutina["dias"].size
    assert rutina["dias"].all? { |d| d["enfoque"].include?("Cuerpo completo") }
  end

  test "sin objetivo usa torso/pierna y la forma de ejercicio es válida" do
    rutina = GeneradorPlanBasico.para(User.new)

    assert_equal 6, rutina["dias"].size
    ejercicio = rutina["dias"].first["ejercicios"].first
    assert_equal %w[descanso_seg nombre repeticiones series], ejercicio.keys.sort
    assert ejercicio["nombre"].present?
  end

  # Fase 6.4: la plantilla enlazada al catálogo propaga su ejercicio_id
  test "incluye ejercicio_id cuando la plantilla está enlazada al catálogo" do
    ejercicio = Ejercicio.create!(dataset_id: "0025", nombre: "Press de banca", nombre_en: "barbell bench press",
                                  musculo: "pecho", categoria: "chest")
    PlantillaEjercicio.find_by(musculo: "pecho", nombre: "Ej pecho").update!(ejercicio: ejercicio)

    rutina = GeneradorPlanBasico.para(users(:one), objetivo: objetivo("superavit"))

    con_id = rutina["dias"].flat_map { |d| d["ejercicios"] }.select { |e| e["ejercicio_id"] }
    assert con_id.any?
    assert_equal ejercicio.id, con_id.first["ejercicio_id"]
  end

  test "la semana rota ejercicios entre repeticiones del mismo enfoque" do
    2.times { |i| PlantillaEjercicio.find_or_create_by!(musculo: "pecho", nombre: "Press extra #{i}") { |p| p.repeticiones = "8" } }
    rutina = GeneradorPlanBasico.para(users(:one), objetivo: objetivo("superavit"))

    lunes = rutina["dias"][0]["ejercicios"].map { |e| e["nombre"] }
    jueves = rutina["dias"][3]["ejercicios"].map { |e| e["nombre"] }
    assert_not_equal lunes, jueves
  end
end
