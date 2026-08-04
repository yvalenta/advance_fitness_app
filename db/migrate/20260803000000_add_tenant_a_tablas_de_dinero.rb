# Desnormaliza `tenant_id` en las tablas de dinero (SDD §16.7, Etapa 1.3 del
# plan de estabilización): hasta ahora su aislamiento se derivaba por join a
# `users` — dos saltos en el caso de `pagos` (`membresia → user`), la cadena
# más larga del dominio y justo sobre el historial financiero.
#
# El backfill va DENTRO de la migración, a diferencia del ritual de
# `multi_tenant:migrar` (§16.6): allí el valor requería decisiones de negocio;
# aquí es derivable y determinista (`user.tenant_id`). Un rake aparte abriría
# una ventana entre el deploy y su ejecución en la que los Pundit Scopes
# —fail-closed por diseño— dejarían al staff sin ver nada.
#
# La columna queda nullable a nivel de base (igual que `users.tenant_id`) para
# que un rollback no falle; la presencia y la coherencia con el dueño las exige
# el modelo.
class AddTenantATablasDeDinero < ActiveRecord::Migration[8.1]
  def up
    # index: false — el índice compuesto de abajo lleva `tenant_id` como
    # columna líder y cubre también las búsquedas por FK (misma higiene de
    # índices de `20260715120000_eliminar_indices_redundantes`).
    add_reference :membresias, :tenant, foreign_key: true, index: false
    add_reference :pagos, :tenant, foreign_key: true, index: false
    add_reference :suscripciones, :tenant, foreign_key: true, index: false

    # Backfill idempotente: `WHERE tenant_id IS NULL` lo hace re-ejecutable sin
    # pisar nada. Set-based, no fila a fila: una sola sentencia por tabla sobre
    # el pooler de 15 conexiones de Supabase (Nota 13).
    execute <<~SQL.squish
      UPDATE membresias SET tenant_id = users.tenant_id
      FROM users
      WHERE users.id = membresias.user_id AND membresias.tenant_id IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE suscripciones SET tenant_id = users.tenant_id
      FROM users
      WHERE users.id = suscripciones.user_id AND suscripciones.tenant_id IS NULL
    SQL

    # `pagos` llega al tenant por membresia → user (los dos saltos que motivan
    # este ADR).
    execute <<~SQL.squish
      UPDATE pagos SET tenant_id = users.tenant_id
      FROM membresias
      INNER JOIN users ON users.id = membresias.user_id
      WHERE membresias.id = pagos.membresia_id AND pagos.tenant_id IS NULL
    SQL

    # Compuestos con `tenant_id` líder + la columna de orden de cada listado
    # admin, para que filtrar por tenant no degrade el ORDER BY que ya existe:
    #   Admin::MembresiasController#index   → order(:fecha_vencimiento)
    #   Admin::PagosController#index        → order(fecha_pago: :desc, id: :desc)
    #   Admin::SuscripcionesController#index → order(created_at: :desc)
    # Postgres recorre el índice hacia atrás para los DESC, así que no hace
    # falta declararlos con orden explícito.
    add_index :membresias, [ :tenant_id, :fecha_vencimiento ]
    add_index :pagos, [ :tenant_id, :fecha_pago, :id ]
    add_index :suscripciones, [ :tenant_id, :created_at ]
  end

  def down
    remove_index :membresias, [ :tenant_id, :fecha_vencimiento ]
    remove_index :pagos, [ :tenant_id, :fecha_pago, :id ]
    remove_index :suscripciones, [ :tenant_id, :created_at ]

    remove_reference :membresias, :tenant, foreign_key: true
    remove_reference :pagos, :tenant, foreign_key: true
    remove_reference :suscripciones, :tenant, foreign_key: true
  end
end
