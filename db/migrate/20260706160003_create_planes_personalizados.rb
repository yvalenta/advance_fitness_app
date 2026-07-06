class CreatePlanesPersonalizados < ActiveRecord::Migration[8.1]
  def change
    create_table :planes_personalizados do |t|
      t.references :user, null: false, foreign_key: true
      t.jsonb :rutina, null: false, default: {}
      t.jsonb :plan_nutricional, null: false, default: {}
      t.string :generado_por, null: false, default: "ia"
      t.string :estado, null: false, default: "borrador"
      t.references :aprobado_por, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :planes_personalizados, %i[user_id estado]
  end
end
