require "test_helper"

class GeneradorPlanBasicoTest < ActiveSupport::TestCase
  setup do
    %w[pecho espalda pierna hombro biceps triceps core gluteo].each do |musculo|
      PlantillaEjercicio.create!(musculo: musculo, nombre: "Ej #{musculo}",
                                 series: 3, repeticiones: "10", descanso_seg: 60)
    end
  end

  test "principiante mayor recibe full-body de 3 días con ejercicios" do
    rutina = GeneradorPlanBasico.para(User.new(fecha_nacimiento: 55.years.ago.to_date))

    assert_equal %w[lunes miercoles viernes], rutina["dias"].map { |dia| dia["dia"] }
    assert rutina["dias"].all? { |dia| dia["ejercicios"].any? }
  end

  test "adulto joven recibe split de 4 días con la forma de ejercicio válida" do
    rutina = GeneradorPlanBasico.para(User.new(fecha_nacimiento: 28.years.ago.to_date))

    assert_equal 4, rutina["dias"].size
    ejercicio = rutina["dias"].first["ejercicios"].first
    assert_equal %w[nombre series repeticiones descanso_seg].sort, ejercicio.keys.sort
    assert ejercicio["nombre"].present?
  end

  test "sin edad conocida usa full-body" do
    assert GeneradorPlanBasico.fullbody?(User.new(fecha_nacimiento: nil))
  end
end
