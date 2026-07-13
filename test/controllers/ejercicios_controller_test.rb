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

  # Fase 6.4: catálogo buscable del editor (turbo-frame, máx. 30)
  test "el índice filtra por texto sin acentos y excluye cardio" do
    Ejercicio.create!(dataset_id: "1160", nombre: "run", nombre_en: "run",
                      musculo: "otro", categoria: "cardio")
    sign_in_as users(:entrenador)

    get ejercicios_path(q: "PRÉSS de banca")

    assert_response :success
    assert_select "turbo-frame#catalogo_ejercicios"
    assert_match "Press de banca con barra", response.body

    get ejercicios_path(q: "run")
    assert_no_match "cardio", response.body
    assert_match "Nada coincide", response.body
  end

  test "la ayuda encuentra por id y renderiza el frame con instrucciones" do
    sign_in_as users(:one)

    get ayuda_ejercicios_path(ejercicio_id: @ejercicio.id)

    assert_response :success
    assert_select "turbo-frame#ayuda_ejercicio"
    assert_match "Press de banca con barra", response.body
    assert_match "Baja la barra al pecho.", response.body
    assert_match "Gym visual", response.body
    assert_select "img[src=?]", media_ejercicio_path(@ejercicio, tipo: :gif)
  end

  test "la ayuda cae al nombre (con acentos) cuando no hay id" do
    sign_in_as users(:one)

    get ayuda_ejercicios_path(nombre: "PRESS de Banca con Barra")

    assert_response :success
    assert_match "Baja la barra al pecho.", response.body
  end

  test "sin match la ayuda muestra el estado amable dentro del frame" do
    sign_in_as users(:one)

    get ayuda_ejercicios_path(nombre: "Sentadilla búlgara")

    assert_response :success
    assert_select "turbo-frame#ayuda_ejercicio"
    assert_match "Sin ayuda visual", response.body
    assert_match "Sentadilla búlgara", response.body
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
