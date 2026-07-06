class CreateObjetivosNutricionales < ActiveRecord::Migration[8.1]
  def change
    create_table :objetivos_nutricionales do |t|
      t.references :user, null: false, foreign_key: true
      t.string :tipo, null: false
      t.decimal :peso_kg, precision: 5, scale: 2, null: false
      t.integer :tdee_kcal, null: false
      t.integer :objetivo_kcal, null: false
      t.boolean :activo, null: false, default: true

      t.timestamps
    end

    # Solo un objetivo activo por usuario (SDD §07)
    add_index :objetivos_nutricionales, :user_id, unique: true, where: "activo",
              name: "index_objetivos_nutricionales_un_activo_por_user"
  end
end
