require "test_helper"

class Ejercicios::MediaCacheTest < ActiveSupport::TestCase
  GIF = "GIF89a\x01\x00\x01\x00".b

  setup do
    @descargas = 0
    Ejercicios::MediaCache.descargador = ->(_url) { @descargas += 1; GIF }
  end

  teardown do
    Ejercicios::MediaCache.descargador = nil
    FileUtils.rm_rf(Ejercicios::MediaCache::RAIZ.join("videos/test"))
  end

  test "descarga una vez y reutiliza la caché después" do
    ruta = "videos/test/0001-abc.gif"

    archivo = Ejercicios::MediaCache.asegurar!(ruta)
    assert archivo.exist?
    assert_equal GIF, archivo.binread

    Ejercicios::MediaCache.asegurar!(ruta)
    assert_equal 1, @descargas
  end

  test "rechaza rutas que escapan de la raíz" do
    assert_raises(Ejercicios::MediaCache::MediaNoDisponible) do
      Ejercicios::MediaCache.asegurar!("../config/master.key")
    end
    assert_equal 0, @descargas
  end

  test "una descarga fallida no deja archivo a medias" do
    Ejercicios::MediaCache.descargador = ->(_url) { raise "timeout" }

    assert_raises(Ejercicios::MediaCache::MediaNoDisponible) do
      Ejercicios::MediaCache.asegurar!("videos/test/0002-xyz.gif")
    end
    assert_not Ejercicios::MediaCache::RAIZ.join("videos/test/0002-xyz.gif").exist?
  end
end
