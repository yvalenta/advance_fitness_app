class AddDetalleARegistrosCalorias < ActiveRecord::Migration[8.1]
  # El miembro puede ajustar lo que realmente comió por comida (kcal + nota);
  # el detalle se guarda junto al total del día (SDD Fase 5.8). Sin tabla nueva.
  def change
    add_column :registros_calorias, :detalle, :jsonb, default: {}, null: false
  end
end
