class CreateAccesos < ActiveRecord::Migration[8.1]
  def change
    create_table :accesos do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :fecha_hora, null: false
      t.string :tipo, null: false, default: "checkin"
      t.boolean :dentro_de_horario, null: false, default: true

      t.timestamps
    end
    add_index :accesos, [ :user_id, :fecha_hora ]
  end
end
