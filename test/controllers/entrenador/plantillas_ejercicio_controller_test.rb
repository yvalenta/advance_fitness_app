require "test_helper"

class Entrenador::PlantillasEjercicioControllerTest < ActionDispatch::IntegrationTest
  PARAMS = { plantilla_ejercicio: { musculo: "espalda", nombre: "Remo en punta",
                                    series: 4, repeticiones: "8-10", descanso_seg: 90 } }.freeze

  test "el entrenador guarda una plantilla desde el editor" do
    sign_in_as users(:entrenador)

    assert_difference "PlantillaEjercicio.count", 1 do
      post entrenador_plantillas_ejercicio_path, params: PARAMS, as: :json
    end
    assert_response :created
    assert_equal users(:entrenador), PlantillaEjercicio.last.creado_por
  end

  test "un miembro no puede crear ni borrar plantillas de ejercicio" do
    sign_in_as users(:one)

    assert_no_difference "PlantillaEjercicio.count" do
      post entrenador_plantillas_ejercicio_path, params: PARAMS, as: :json
      delete entrenador_plantilla_ejercicio_path(plantillas_ejercicio(:sentadilla))
    end
  end

  test "el staff puede retirar una plantilla" do
    sign_in_as users(:admin)

    assert_difference "PlantillaEjercicio.count", -1 do
      delete entrenador_plantilla_ejercicio_path(plantillas_ejercicio(:sentadilla))
    end
  end
end
