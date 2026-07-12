# Caché en disco para el media del catálogo (SDD Fase 6.2). Los GIFs/imágenes
# viven en el repo del dataset; descargarlos todos engordaría la imagen Docker
# y hotlinkear expondría al miembro a GitHub. En su lugar: la primera petición
# descarga el archivo al volumen persistente (storage/, montado por Kamal) y
# las siguientes se sirven locales. Los nombres traen hash (0001-2gPfomN.gif),
# así que el contenido es inmutable y cacheable para siempre.
module Ejercicios
  module MediaCache
    class MediaNoDisponible < StandardError; end

    RAIZ = Rails.root.join("storage", "ejercicios_media")
    BASE_URL = ENV.fetch("EJERCICIOS_MEDIA_BASE",
                         "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/").freeze

    # Devuelve la ruta local del archivo, descargándolo si aún no está.
    def self.asegurar!(ruta_relativa)
      destino = ruta_segura(ruta_relativa)
      return destino if destino.exist?

      descargar(ruta_relativa, destino)
      destino
    end

    # Anti path-traversal: el destino debe quedar bajo RAIZ sí o sí.
    def self.ruta_segura(ruta_relativa)
      destino = RAIZ.join(ruta_relativa.to_s).expand_path
      raise MediaNoDisponible, "ruta inválida" unless destino.to_s.start_with?(RAIZ.to_s + File::SEPARATOR)

      destino
    end

    def self.descargar(ruta_relativa, destino)
      contenido = descargador.call(BASE_URL + ruta_relativa.to_s)
      raise MediaNoDisponible, "descarga vacía" if contenido.blank?

      destino.dirname.mkpath
      # Escritura atómica: nunca dejar un archivo a medias visible
      temporal = destino.sub_ext("#{destino.extname}.tmp#{Process.pid}")
      temporal.binwrite(contenido)
      FileUtils.mv(temporal, destino)
    rescue MediaNoDisponible
      raise
    rescue StandardError => e
      raise MediaNoDisponible, e.message
    end

    # Inyectable en tests; en producción baja por HTTPS con timeouts cortos.
    def self.descargador
      @descargador ||= lambda do |url|
        respuesta = Net::HTTP.start(URI(url).host, 443, use_ssl: true,
                                    open_timeout: 5, read_timeout: 20) do |http|
          http.get(URI(url).path)
        end
        raise MediaNoDisponible, "HTTP #{respuesta.code}" unless respuesta.is_a?(Net::HTTPSuccess)

        respuesta.body
      end
    end

    class << self
      attr_writer :descargador
    end
  end
end
