# Catálogo visual de ejercicios (SDD Fase 6): importación del dataset y
# utilidades asociadas. Todas idempotentes — seguras contra producción.
namespace :ejercicios do
  desc "Importa el catálogo desde el dataset (URL raw de GitHub o ruta local)"
  task :importar, [ :origen ] => :environment do |_t, args|
    origen = args[:origen].presence || Ejercicios::ImportadorDataset::ORIGEN_DEFAULT
    puts "Importando desde #{origen}…"

    resumen = Ejercicios::ImportadorDataset.importar(origen)
    puts "✓ Ejercicios — creados: #{resumen[:creados]} · actualizados: #{resumen[:actualizados]} · " \
         "sin cambio: #{resumen[:sin_cambio]} · total en base: #{Ejercicio.count}"
  end

  desc "Traduce al español (con IA) los nombres que siguen en inglés"
  task traducir_nombres: :environment do
    pendientes = Ejercicio.where("nombre = nombre_en").count
    puts "Pendientes de traducir: #{pendientes}"

    total = Ejercicios::TraductorNombres.traducir_pendientes do |avance|
      puts "  … #{avance} traducidos"
    end
    puts "✓ Traducidos: #{total} · aún en inglés: #{Ejercicio.where('nombre = nombre_en').count}"
  end

  desc "Pre-descarga el media (gif + imagen) de los ejercicios enlazados a plantillas"
  task precalentar_media: :environment do
    ejercicios = Ejercicio.joins(:plantillas_ejercicio).distinct
    ejercicios.find_each do |ejercicio|
      [ ejercicio.gif_ruta, ejercicio.imagen_ruta ].compact_blank.each do |ruta|
        Ejercicios::MediaCache.asegurar!(ruta)
      rescue Ejercicios::MediaCache::MediaNoDisponible => e
        puts "✗ #{ejercicio.nombre} (#{ruta}): #{e.message}"
      end
      puts "✓ #{ejercicio.nombre}"
    end
    puts "Media en caché: #{Dir.glob(Ejercicios::MediaCache::RAIZ.join('**/*')).count { |f| File.file?(f) }} archivos"
  end
end
