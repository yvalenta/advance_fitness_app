# Arranque de tenant (SDD §16 — visión multi-gimnasio): comando único que
# deja la base del tenant lista para operar. Es el paso "datos" del runbook
# de alta; los pasos de infraestructura (base nueva, ENV/secrets, deploy,
# túnel, OAuth) son manuales y se listan en el reporte final.
#
# Uso (local vía dip, o dentro del contenedor del tenant en producción):
#   bin/rails tenant:preparar
#
# Orden y racionales:
#   1. db:prepare        crea la base si no existe y aplica el schema/migraciones.
#   2. db:seed           admin, catálogo de planes y bibliotecas curadas (db/seeds.rb).
#   3. ejercicios:importar + traducir_nombres   catálogo visual (~1.324 filas);
#      requiere red y GEMINI_API_KEY/ANTHROPIC_API_KEY — si falla, el tenant
#      queda operativo igual (solo sin GIFs de ayuda) y se reintenta después.
#   4. db:seed (de nuevo)  fija los vínculos plantilla→ejercicio que la primera
#      corrida no pudo hacer con el catálogo vacío (sección 5 del seed).
#
# Idempotente de punta a punta: cada paso lo es por sí mismo (ver db/seeds.rb
# y lib/tasks/ejercicios.rake), así que re-correrla es siempre seguro.
namespace :tenant do
  desc "Prepara la base de un tenant: schema + seed + catálogo de ejercicios + reporte"
  task preparar: :environment do
    puts "═══ Arranque de tenant ═══"

    puts "→ 1/4 Schema (db:prepare)…"
    Rake::Task["db:prepare"].invoke

    puts "→ 2/4 Seed base (db:seed)…"
    Rake::Task["db:seed"].invoke

    puts "→ 3/4 Catálogo visual de ejercicios…"
    begin
      Rake::Task["ejercicios:importar"].invoke
      Rake::Task["ejercicios:traducir_nombres"].invoke
    rescue StandardError => error
      puts "  ✗ No se pudo completar el catálogo (#{error.message.to_s.truncate(120)})."
      puts "    El tenant queda operativo sin GIFs de ayuda; reintenta luego con:"
      puts "    bin/rails ejercicios:importar ejercicios:traducir_nombres db:seed"
    end

    puts "→ 4/4 Re-seed (vínculos plantilla→ejercicio)…"
    Rake::Task["db:seed"].reenable
    Rake::Task["db:seed"].invoke

    vinculadas = PlantillaEjercicio.where.not(ejercicio_id: nil).count
    puts <<~REPORTE

      ═══ Reporte del tenant ═══
      Usuarios:                #{User.count} (admins: #{User.where(rol: "admin").count})
      Planes (catálogo):       #{Plan.count}
      Plantillas de comida:    #{PlantillaComida.count}
      Plantillas de ejercicio: #{PlantillaEjercicio.count} (#{vinculadas} vinculadas al catálogo)
      Catálogo de ejercicios:  #{Ejercicio.count}

      Pasos manuales pendientes (runbook completo en advance-fitness-sdd.md §16):
      · ENV de marca/precios del tenant: NEGOCIO_NOMBRE, NEGOCIO_LOGO_URL,
        PRECIO_MENSUALIDAD, PRECIO_PERSONALIZADO, MEMBRESIA_DURACION_DIAS.
      · SEED_ADMIN_EMAIL/SEED_ADMIN_PASSWORD reales (o ADMIN_EMAIL para promover
        una cuenta de Google) y cambiar la contraseña del admin sembrado.
      · OAuth de Google: registrar https://<subdominio>/auth/google_oauth2/callback.
      · Túnel Cloudflare: ingress del subdominio → alias del contenedor.
      · Deploy Kamal del tenant (config/deploy.<tenant>.yml + secrets propios).
    REPORTE
  end
end
