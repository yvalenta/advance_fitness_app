require "test_helper"

class EjerciciosControllerTest < ActionDispatch::IntegrationTest
  GIF = "GIF89a\x01\x00\x01\x00".b

  setup do
    @ejercicio = Ejercicio.create!(dataset_id: "0025", nombre: "Press de banca con barra",
                                   nombre_en: "barbell bench press", musculo: "pecho",
                                   categoria: "chest", equipo: "barbell",
                                   instrucciones: [ "Acuéstate en el banco.", "Baja la barra al pecho." ],
                                   gif_ruta: "videos/test/0025-abc.gif",
                                   imagen_ruta: "images/test/0025-abc.jpg")
    Ejercicios::MediaCache.descargador = ->(_url) { GIF }
  end

  teardown do
    Ejercicios::MediaCache.descargador = nil
    FileUtils.rm_rf(Ejercicios::MediaCache::RAIZ.join("videos/test"))
    FileUtils.rm_rf(Ejercicios::MediaCache::RAIZ.join("images/test"))
  end

  test "el media requiere sesión" do
    get media_ejercicio_path(@ejercicio, tipo: "gif")
    assert_redirected_to new_session_path
  end

  test "sirve el gif con caché pública de un año" do
    sign_in_as users(:one)

    get media_ejercicio_path(@ejercicio, tipo: "gif")

    assert_response :success
    assert_equal "image/gif", response.media_type
    assert_match(/public/, response.headers["Cache-Control"])
    assert_match(/max-age=31556952/, response.headers["Cache-Control"])
  end

  test "media inexistente o descarga fallida responde 404" do
    sign_in_as users(:one)
    Ejercicios::MediaCache.descargador = ->(_url) { raise "no llega" }

    get media_ejercicio_path(@ejercicio, tipo: "imagen")
    assert_response :not_found

    @ejercicio.update!(gif_ruta: nil)
    get media_ejercicio_path(@ejercicio, tipo: "gif")
    assert_response :not_found
  end

  test "un tipo fuera de gif|imagen no rutea" do
    sign_in_as users(:one)
    get "/ejercicios/#{@ejercicio.id}/media/pdf"
    assert_response :not_found
  end
end
