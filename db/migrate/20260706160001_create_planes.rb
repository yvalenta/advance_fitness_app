class CreatePlanes < ActiveRecord::Migration[8.1]
  def change
    create_table :planes do |t|
      t.string :codigo, null: false
      t.string :nombre, null: false
      t.decimal :precio, precision: 10, scale: 0, null: false, default: 0
      t.jsonb :beneficios, null: false, default: []

      t.timestamps
    end

    add_index :planes, :codigo, unique: true
  end
end
