require "rails_helper"

RSpec.describe "Ejercicios", type: :request do
  gif = "GIF89a\x01\x00\x01\x00".b

  before do
    @ejercicio = Ejercicio.create!(dataset_id: "0025", nombre: "Press de banca con barra",
                                   nombre_en: "barbell bench press", musculo: "pecho",
                                   categoria: "chest", equipo: "barbell",
                                   instrucciones: [ "Acuéstate en el banco.", "Baja la barra al pecho." ],
                                   gif_ruta: "videos/test/0025-abc.gif",
                                   imagen_ruta: "images/test/0025-abc.jpg")
    Ejercicios::MediaCache.descargador = ->(_url) { gif }
  end

  after do
    Ejercicios::MediaCache.descargador = nil
    FileUtils.rm_rf(Ejercicios::MediaCache::RAIZ.join("videos/test"))
    FileUtils.rm_rf(Ejercicios::MediaCache::RAIZ.join("images/test"))
  end

  # Fase 6.4: catálogo buscable del editor (turbo-frame, máx. 30)
  it "el índice filtra por texto sin acentos y excluye cardio" do
    Ejercicio.create!(dataset_id: "1160", nombre: "run", nombre_en: "run",
                      musculo: "otro", categoria: "cardio")
    sign_in_as users(:entrenador)

    get ejercicios_path(q: "PRÉSS de banca")

    expect(response).to have_http_status(:success)
    assert_select "turbo-frame#catalogo_ejercicios"
    expect(response.body).to include("Press de banca con barra")

    get ejercicios_path(q: "run")
    expect(response.body).not_to include("cardio")
    expect(response.body).to include("Nada coincide")
  end

  it "la ayuda encuentra por id y renderiza el frame con instrucciones" do
    sign_in_as users(:one)

    get ayuda_ejercicios_path(ejercicio_id: @ejercicio.id)

    expect(response).to have_http_status(:success)
    assert_select "turbo-frame#ayuda_ejercicio"
    expect(response.body).to include("Press de banca con barra")
    expect(response.body).to include("Baja la barra al pecho.")
    expect(response.body).to include("Gym visual")
    assert_select "img[src=?]", media_ejercicio_path(@ejercicio, tipo: :gif)
  end

  it "la ayuda cae al nombre (con acentos) cuando no hay id" do
    sign_in_as users(:one)

    get ayuda_ejercicios_path(nombre: "PRESS de Banca con Barra")

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Baja la barra al pecho.")
  end

  it "sin match la ayuda muestra el estado amable dentro del frame" do
    sign_in_as users(:one)

    get ayuda_ejercicios_path(nombre: "Sentadilla búlgara")

    expect(response).to have_http_status(:success)
    assert_select "turbo-frame#ayuda_ejercicio"
    expect(response.body).to include("Sin ayuda visual")
    expect(response.body).to include("Sentadilla búlgara")
  end

  it "el media requiere sesión" do
    get media_ejercicio_path(@ejercicio, tipo: "gif")
    expect(response).to redirect_to(new_session_path)
  end

  it "sirve el gif con caché pública de un año" do
    sign_in_as users(:one)

    get media_ejercicio_path(@ejercicio, tipo: "gif")

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq("image/gif")
    expect(response.headers["Cache-Control"]).to match(/public/)
    expect(response.headers["Cache-Control"]).to match(/max-age=31556952/)
  end

  it "media inexistente o descarga fallida responde 404" do
    sign_in_as users(:one)
    Ejercicios::MediaCache.descargador = ->(_url) { raise "no llega" }

    get media_ejercicio_path(@ejercicio, tipo: "imagen")
    expect(response).to have_http_status(:not_found)

    @ejercicio.update!(gif_ruta: nil)
    get media_ejercicio_path(@ejercicio, tipo: "gif")
    expect(response).to have_http_status(:not_found)
  end

  it "un tipo fuera de gif|imagen no rutea" do
    sign_in_as users(:one)
    get "/ejercicios/#{@ejercicio.id}/media/pdf"
    expect(response).to have_http_status(:not_found)
  end

  # Fase 14.5: explorador por músculo — la MISMA vista para miembro y staff
  # (el catálogo es global por diseño, SDD §16.6: sin spec de aislamiento).
  describe "explorador del catálogo" do
    it "sin filtros, el miembro ve las categorías agrupadas con portada y conteo" do
      sign_in_as users(:one)

      get ejercicios_path

      expect(response).to have_http_status(:success)
      # Página completa: hero + buscador dentro del frame (se conserva para el modal)
      expect(response.body).to include("Explora los ejercicios")
      assert_select "turbo-frame#catalogo_ejercicios input[name=?]", "q"
      # Card de la categoría: nombre en español, conteo y portada representativa
      expect(response.body).to include("Pecho")
      expect(response.body).to include("1 ejercicio")
      assert_select "a[href=?]", ejercicios_path(musculo: "pecho")
      assert_select "img[src=?]", media_ejercicio_path(@ejercicio, tipo: :imagen)
    end

    it "una categoría lleva al listado filtrado con su volver a categorías" do
      sign_in_as users(:one)

      get ejercicios_path(musculo: "pecho")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Press de banca con barra")
      assert_select "a[href=?]", ejercicios_path, text: /Categorías/
    end

    it "el staff ve el mismo explorador (no se bifurca la vista)" do
      sign_in_as users(:entrenador)

      get ejercicios_path

      expect(response.body).to include("1 ejercicio")
      assert_select "a[href=?]", ejercicios_path(musculo: "pecho")
    end

    it "el miembro también puede buscar en el catálogo (ya no es solo del editor)" do
      sign_in_as users(:one)

      get ejercicios_path(q: "press de banca")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Press de banca con barra")
    end
  end
end
