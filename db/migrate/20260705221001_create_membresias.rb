class CreateMembresias < ActiveRecord::Migration[8.1]
  def change
    create_table :membresias do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.date :fecha_inicio, null: false
      t.date :fecha_vencimiento, null: false
      t.string :estado, null: false, default: "activa"
      t.jsonb :horario_acceso

      t.timestamps
    end
    add_index :membresias, :estado
  end
end
