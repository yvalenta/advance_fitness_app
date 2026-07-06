class CreateRegistrosCalorias < ActiveRecord::Migration[8.1]
  def change
    create_table :registros_calorias do |t|
      t.references :user, null: false, foreign_key: true
      t.date :fecha, null: false
      t.integer :kcal_consumidas, null: false

      t.timestamps
    end

    # Un registro por día (SDD §07); el POST hace upsert
    add_index :registros_calorias, %i[user_id fecha], unique: true
  end
end
