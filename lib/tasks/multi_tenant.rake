# Backfill de multi-tenancy row-level (SDD §16.6): se corre A MANO tras el
# deploy que introduce el esquema de tenants, con confirmación explícita
# (mismo ritual que demo:sembrar). Idempotente — se puede correr N veces sin
# duplicar ni pisar datos ya editados.
#
# Uso:
#   dip rails multi_tenant:migrar
#   bin/kamal app exec --interactive --reuse "bin/rails multi_tenant:migrar"
#
# ENV opcionales:
#   SUPERADMIN_EMAIL       correo del superadmin global (default: super@advancefitness.local)
#   SUPERADMIN_PASSWORD    contraseña inicial (default: cambiame-super-123)
#   COMERCIALIZADOR_EMAIL  correo del usuario semilla comercializador
#                          (default: comercial@advancefitness.local)
#   COMERCIALIZADOR_NOMBRE nombre visible (default: "Comercial Advance Fitness")
namespace :multi_tenant do
  desc "Crea tenant Advance Fitness, asocia datos existentes, crea superadmin y comercializador"
  task migrar: :environment do
    puts "═══ Backfill multi-tenant ═══"

    tenant_af = Tenant.find_or_initialize_by(slug: "advance-fitness")
    tenant_af.update!(
      nombre: tenant_af.nombre.presence || "Advance Fitness",
      tipo_entidad: tenant_af.tipo_entidad.presence || "gimnasio",
      email_contacto: tenant_af.email_contacto.presence || "megaplex.med@gmail.com",
      features_habilitadas: tenant_af.features_habilitadas.presence || { "membresias" => true },
      activo: true
    )
    puts "→ Tenant AF listo (id=#{tenant_af.id})"

    users_sin = User.where(tenant_id: nil).where.not(rol: User::ROLES_GLOBALES)
    puts "→ Asociando #{users_sin.count} usuario(s) a AF…"
    users_sin.update_all(tenant_id: tenant_af.id)

    if defined?(Post)
      posts_sin = Post.where(tenant_id: nil)
      puts "→ Asociando #{posts_sin.count} post(s) a AF…"
      posts_sin.update_all(tenant_id: tenant_af.id)
    end

    if defined?(Novedad)
      novedades_sin = Novedad.where(tenant_id: nil)
      puts "→ Asociando #{novedades_sin.count} novedad(es) a AF…"
      novedades_sin.update_all(tenant_id: tenant_af.id)
    end

    super_email = ENV.fetch("SUPERADMIN_EMAIL", "super@advancefitness.local")
    superadmin = User.find_or_initialize_by(email_address: super_email)
    if superadmin.new_record?
      superadmin.assign_attributes(
        nombre: "Superadmin",
        rol: "superadmin",
        password: ENV.fetch("SUPERADMIN_PASSWORD", "cambiame-super-123"),
        tenant: nil
      )
      superadmin.save!
      puts "→ Superadmin creado: #{super_email}"
    else
      superadmin.update!(rol: "superadmin", tenant: nil) unless superadmin.superadmin?
      puts "→ Superadmin existente: #{super_email}"
    end

    comer_email = ENV.fetch("COMERCIALIZADOR_EMAIL", "comercial@advancefitness.local")
    comer_nombre = ENV.fetch("COMERCIALIZADOR_NOMBRE", "Comercial Advance Fitness")
    comercializador = User.find_or_initialize_by(email_address: comer_email)
    if comercializador.new_record?
      comercializador.assign_attributes(
        nombre: comer_nombre,
        rol: "comercializador",
        password: SecureRandom.base58(32),
        tenant: nil
      )
      comercializador.save!
      PasswordsMailer.reset(comercializador).deliver_later
      puts "→ Comercializador creado: #{comer_email} (correo de fijar contraseña enviado)"
    else
      puts "→ Comercializador existente: #{comer_email}"
    end

    puts
    puts "═══ Reporte ═══"
    puts "  Tenants:              #{Tenant.count}"
    puts "  Users totales:        #{User.count}"
    puts "  Users sin tenant:     #{User.where(tenant_id: nil).count} (esperado: superadmin + comercializador = #{User.where(rol: User::ROLES_GLOBALES).count})"
    puts "  Users en AF:          #{tenant_af.users.count}"
    huerfanos = User.where(tenant_id: nil).where.not(rol: User::ROLES_GLOBALES)
    if huerfanos.any?
      puts "  ⚠ Users huérfanos (sin tenant y sin rol global): #{huerfanos.pluck(:email_address).join(", ")}"
    end
  end
end
