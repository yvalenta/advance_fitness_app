# Log append-only del cambio de organización (tarea 2026-08-31): cada salto
# de un subdominio a otro deja una FILA — quién, de dónde, a dónde, IP y
# user-agent — con el mismo espíritu auditable que `consentimientos` y
# `pagos`: se deja rastro, jamás se edita ni se borra físico. Sin
# updated_at: una fila nace y no cambia.
#
# `token_digest` guarda el digest del pase firmado con el que se canjeó el
# salto, y su índice ÚNICO es el candado del UN SOLO USO: canjear el mismo
# pase dos veces choca contra el único en la base, sin depender de la
# aplicación. nil permitido — Postgres no compara NULLs entre sí, así que
# las filas de auditoría sin pase (p. ej. superadmin entrando a un tenant)
# conviven sin chocar.
#
# `de_tenant_id` es nullable: el salto puede arrancar fuera de un tenant
# (portal comercial, donde Current.tenant es nil).
class CrearCambiosOrganizacion < ActiveRecord::Migration[8.1]
  def change
    create_table :cambios_organizacion do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :de_tenant, foreign_key: { to_table: :tenants }, index: false
      t.references :a_tenant, null: false, foreign_key: { to_table: :tenants }, index: false
      t.string :ip
      t.string :user_agent
      t.string :token_digest
      t.datetime :created_at, null: false
    end

    # El candado del UN SOLO USO del pase firmado.
    add_index :cambios_organizacion, :token_digest, unique: true
    # Auditoría por cuenta en orden cronológico (cubre el prefijo user_id,
    # por eso `references` no crea su índice propio).
    add_index :cambios_organizacion, [ :user_id, :created_at ]
  end
end
