# La pieza N:M del multi-tenant (tarea 2026-08-31): hoy `users.tenant_id`
# obliga a que una persona exista UNA vez por gimnasio — un dueño de dos
# gimnasios necesita dos cuentas, con dos passwords y dos perfiles. `puestos`
# separa la CUENTA (users) de la PERTENENCIA: un puesto por gimnasio, con el
# rol que la cuenta tiene AHÍ. `users.tenant_id`/`users.rol` pasan a ser la
# cache de "dónde está parada la cuenta ahora" (contrato redefinido en User).
#
# El backfill va DENTRO de la migración, mismo criterio que
# `20260803000000_add_tenant_a_tablas_de_dinero`: el valor es derivable y
# determinista (cada user con tenant ya ES su único puesto, con su rol
# actual), y un rake aparte abriría una ventana entre el deploy y su
# ejecución en la que `verificar_pertenencia_al_tenant` — que pasará a mirar
# `puestos` — echaría a todo el mundo. Los roles globales
# (superadmin/comercializador) NO migran: operan el portal comercial, no
# pertenecen a ningún gimnasio.
class CrearPuestos < ActiveRecord::Migration[8.1]
  def change
    create_table :puestos do |t|
      # index: false — el único compuesto de abajo cubre el prefijo user_id,
      # por eso `references` no crea su índice propio.
      t.references :user, null: false, foreign_key: true, index: false
      t.references :tenant, null: false, foreign_key: true, index: false
      t.string :rol, null: false
      t.timestamps
    end

    # Un solo puesto por (cuenta, gimnasio): el rol dentro de un tenant es
    # único; tener dos roles en el MISMO gimnasio no existe en el dominio.
    add_index :puestos, [ :user_id, :tenant_id ], unique: true
    # Los listados por gimnasio (staff del tenant, conteos) entran por acá.
    add_index :puestos, :tenant_id

    reversible do |dir|
      dir.up do
        # Idempotente gracias al ON CONFLICT sobre el único (user_id,
        # tenant_id): re-ejecutar no duplica ni pisa. Set-based, no fila a
        # fila: una sola sentencia sobre el pooler de 15 conexiones (Nota 13).
        execute <<~SQL.squish
          INSERT INTO puestos (user_id, tenant_id, rol, created_at, updated_at)
          SELECT id, tenant_id, rol, NOW(), NOW()
          FROM users
          WHERE tenant_id IS NOT NULL
            AND rol NOT IN ('superadmin', 'comercializador')
          ON CONFLICT (user_id, tenant_id) DO NOTHING
        SQL
      end
    end
  end
end
