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
end
