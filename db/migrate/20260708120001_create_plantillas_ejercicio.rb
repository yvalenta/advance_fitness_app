class CreatePlantillasEjercicio < ActiveRecord::Migration[8.1]
  def change
    create_table :plantillas_ejercicio do |t|
      t.string :musculo, null: false
      t.string :nombre, null: false
      t.integer :series, null: false, default: 3
      t.string :repeticiones, null: false, default: "10-12"
      t.integer :descanso_seg, null: false, default: 60
      t.references :creado_por, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :plantillas_ejercicio, %i[musculo nombre], unique: true
  end
end
