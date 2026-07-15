class CreateNovedades < ActiveRecord::Migration[8.1]
  def change
    create_table :novedades do |t|
      t.string :titulo, null: false
      t.text :contenido, null: false
      t.date :fecha_evento
      t.boolean :publicado, null: false, default: false

      t.timestamps
    end
  end
end
