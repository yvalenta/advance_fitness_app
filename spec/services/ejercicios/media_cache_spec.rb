require "rails_helper"

RSpec.describe Ejercicios::MediaCache, type: :model do
  gif = "GIF89a\x01\x00\x01\x00".b

  before do
    @descargas = 0
    Ejercicios::MediaCache.descargador = ->(_url) { @descargas += 1; gif }
  end

  after do
    Ejercicios::MediaCache.descargador = nil
    FileUtils.rm_rf(Ejercicios::MediaCache::RAIZ.join("videos/test"))
  end

  it "descarga una vez y reutiliza la caché después" do
    ruta = "videos/test/0001-abc.gif"

    archivo = Ejercicios::MediaCache.asegurar!(ruta)
    expect(archivo.exist?).to be_truthy
    expect(archivo.binread).to eq(gif)

    Ejercicios::MediaCache.asegurar!(ruta)
    expect(@descargas).to eq(1)
  end

  it "rechaza rutas que escapan de la raíz" do
    expect {
      Ejercicios::MediaCache.asegurar!("../config/master.key")
    }.to raise_error(Ejercicios::MediaCache::MediaNoDisponible)
    expect(@descargas).to eq(0)
  end

  it "una descarga fallida no deja archivo a medias" do
    Ejercicios::MediaCache.descargador = ->(_url) { raise "timeout" }

    expect {
      Ejercicios::MediaCache.asegurar!("videos/test/0002-xyz.gif")
    }.to raise_error(Ejercicios::MediaCache::MediaNoDisponible)
    expect(Ejercicios::MediaCache::RAIZ.join("videos/test/0002-xyz.gif").exist?).to be_falsey
  end
end
