class AddPerfilToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :nombre, :string, null: false, default: ""
    add_column :users, :fecha_nacimiento, :date
    add_column :users, :sexo, :string
    add_column :users, :talla_cm, :decimal, precision: 5, scale: 1
    add_column :users, :fecha_ingreso, :date, null: false, default: -> { "CURRENT_DATE" }
    add_column :users, :somatotipo, :string
    add_column :users, :nivel_actividad, :decimal, precision: 2, scale: 1
    add_column :users, :rol, :string, null: false, default: "miembro"
    add_index :users, :rol
  end
end
