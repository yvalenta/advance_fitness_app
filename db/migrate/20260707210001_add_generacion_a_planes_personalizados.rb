class AddGeneracionAPlanesPersonalizados < ActiveRecord::Migration[8.1]
  def change
    add_column :planes_personalizados, :error_generacion, :text
    add_column :planes_personalizados, :modelo_generacion, :string
    add_column :planes_personalizados, :intentos, :integer, null: false, default: 0
  end
end
