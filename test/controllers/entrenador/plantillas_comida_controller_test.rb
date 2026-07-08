require "test_helper"

class Entrenador::PlantillasComidaControllerTest < ActionDispatch::IntegrationTest
  PARAMS = { plantilla_comida: { tipo: "almuerzo", nombre: "Bowl de pollo · 600 kcal",
                                 descripcion: "Pollo con arroz y aguacate.", kcal: 600,
                                 proteinas_g: 45, carbohidratos_g: 70, grasas_g: 18 } }.freeze

  test "el entrenador guarda una plantilla desde el editor" do
    sign_in_as users(:entrenador)

    assert_difference "PlantillaComida.count" do
      post entrenador_plantillas_comida_path, params: PARAMS, as: :json
    end

    assert_response :created
    plantilla = PlantillaComida.last
    assert_equal "Bowl de pollo · 600 kcal", plantilla.nombre
    assert_equal users(:entrenador), plantilla.creado_por
    assert_equal "almuerzo", response.parsed_body["tipo"]
  end

  test "una plantilla duplicada devuelve el error" do
    sign_in_as users(:entrenador)
    existente = plantillas_comida(:desayuno_avena)

    post entrenador_plantillas_comida_path, as: :json,
         params: { plantilla_comida: existente.attributes.slice(
           "tipo", "nombre", "descripcion", "kcal", "proteinas_g", "carbohidratos_g", "grasas_g"
         ) }

    assert_response :unprocessable_entity
    assert response.parsed_body["errores"].any?
  end

  test "un miembro no puede crear ni borrar plantillas" do
    sign_in_as users(:one)

    assert_no_difference "PlantillaComida.count" do
      post entrenador_plantillas_comida_path, params: PARAMS, as: :json
      delete entrenador_plantilla_comida_path(plantillas_comida(:cena_ligera))
    end
  end

  test "el staff puede retirar una plantilla" do
    sign_in_as users(:admin)

    assert_difference "PlantillaComida.count", -1 do
      delete entrenador_plantilla_comida_path(plantillas_comida(:cena_ligera))
    end
  end
end
