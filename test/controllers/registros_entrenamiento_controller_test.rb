require "test_helper"

class RegistrosEntrenamientoControllerTest < ActionDispatch::IntegrationTest
  test "el miembro marca un ejercicio del día (upsert por fecha)" do
    sign_in_as users(:one)

    assert_difference "RegistroEntrenamiento.count", 1 do
      post registros_entrenamiento_path, as: :json, params: {
        fecha: Date.current.iso8601, indice: 0, hecho: true, nota: "subí peso", nombre: "Press banca"
      }
    end
    assert_response :success

    registro = users(:one).registros_entrenamiento.find_by(fecha: Date.current)
    assert_equal true, registro.estado_de(0)["hecho"]
    assert_equal "subí peso", registro.estado_de(0)["nota"]
  end

  test "marcar el mismo día otro ejercicio no duplica la fila" do
    sign_in_as users(:one)
    users(:one).registros_entrenamiento.create!(fecha: Date.current)

    assert_no_difference "RegistroEntrenamiento.count" do
      post registros_entrenamiento_path, as: :json, params: {
        fecha: Date.current.iso8601, indice: 1, hecho: true, nombre: "Fondos"
      }
    end
  end

  test "puede marcar un día pasado" do
    sign_in_as users(:one)
    ayer = Date.yesterday

    post registros_entrenamiento_path, as: :json,
         params: { fecha: ayer.iso8601, indice: 0, hecho: true, nombre: "Remo" }

    assert users(:one).registros_entrenamiento.find_by(fecha: ayer).estado_de(0)["hecho"]
  end

  # Fase 5.11: novedad para toda la rutina del día
  test "guarda la novedad del día sin tocar los checks" do
    sign_in_as users(:one)
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    registro.marcar!(0, hecho: true, nombre: "Press banca")

    post registros_entrenamiento_path, as: :json,
         params: { fecha: Date.current.iso8601, novedad: "entrené en otra sede" }

    assert_response :success
    assert_equal "entrené en otra sede", registro.reload.novedad
    assert_equal true, registro.estado_de(0)["hecho"]
  end

  test "marcar sin nota conserva la nota previa" do
    sign_in_as users(:one)
    registro = users(:one).registros_entrenamiento.create!(fecha: Date.current)
    registro.marcar!(0, hecho: true, nota: "con mancuernas", nombre: "Press")

    post registros_entrenamiento_path, as: :json,
         params: { fecha: Date.current.iso8601, indice: 0, hecho: false, nombre: "Press" }

    estado = registro.reload.estado_de(0)
    assert_equal false, estado["hecho"]
    assert_equal "con mancuernas", estado["nota"]
  end

  test "sin sesión no registra" do
    assert_no_difference "RegistroEntrenamiento.count" do
      post registros_entrenamiento_path, as: :json, params: { fecha: Date.current.iso8601, indice: 0, hecho: true }
    end
    assert_response :redirect
  end
end
