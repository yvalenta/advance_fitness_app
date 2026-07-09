class CreateRegistrosEntrenamiento < ActiveRecord::Migration[8.1]
  # Seguimiento de ejercicios del miembro (SDD §07, Fase 5.10): una fila por día
  # con el estado por ejercicio { "<indice>": { hecho, nota, nombre } }.
  def change
    create_table :registros_entrenamiento do |t|
      t.references :user, null: false, foreign_key: true
      t.date :fecha, null: false
      t.jsonb :ejercicios, default: {}, null: false
      t.timestamps
    end

    add_index :registros_entrenamiento, [ :user_id, :fecha ], unique: true
  end
end
