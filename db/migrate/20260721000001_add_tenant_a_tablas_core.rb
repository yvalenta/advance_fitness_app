# tenant_id es nullable a nivel de columna para permitir:
#   · superadmin y comercializador (sin tenant),
#   · el backfill de datos existentes vía multi_tenant:migrar (se corre a mano
#     en producción tras el deploy). El modelo valida presencia según el rol.
# Posts/novedades no tienen backfill fácil sin conocer autoría; el modelo
# valida presencia y el rake task los asocia al tenant Advance Fitness.
class AddTenantATablasCore < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :tenant, foreign_key: true
    add_reference :posts, :tenant, foreign_key: true
    add_reference :novedades, :tenant, foreign_key: true
  end
end
