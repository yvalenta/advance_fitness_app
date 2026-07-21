# Row-level multi-tenancy por subdominio (SDD §16.6): cada gimnasio/entrenador/
# influencer vive en la misma base y se resuelve por `{slug}.ynt.codes`.
# Los precios/duración quedan por tenant (fallback a Negocio.* si nulos).
class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :nombre, null: false
      t.string :slug, null: false
      t.string :tipo_entidad, null: false
      t.string :email_contacto, null: false
      t.jsonb :paleta_colores, null: false, default: {}
      t.jsonb :features_habilitadas, null: false, default: { membresias: true }
      t.integer :precio_mensualidad
      t.integer :precio_personalizado
      t.integer :duracion_dias
      t.boolean :activo, null: false, default: true

      t.timestamps
    end

    add_index :tenants, :slug, unique: true
  end
end
