class CreatePlantillasComida < ActiveRecord::Migration[8.1]
  def change
    create_table :plantillas_comida do |t|
      t.string :tipo, null: false
      t.string :nombre, null: false
      t.text :descripcion, null: false
      t.integer :kcal, null: false
      t.decimal :proteinas_g, precision: 5, scale: 1, null: false, default: 0
      t.decimal :carbohidratos_g, precision: 5, scale: 1, null: false, default: 0
      t.decimal :grasas_g, precision: 5, scale: 1, null: false, default: 0
      t.references :creado_por, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :plantillas_comida, %i[tipo nombre], unique: true
  end
end
