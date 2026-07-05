class CreatePagos < ActiveRecord::Migration[8.1]
  def change
    create_table :pagos do |t|
      t.references :membresia, null: false, foreign_key: true
      t.decimal :monto, precision: 10, scale: 0, null: false
      t.date :fecha_pago, null: false
      t.date :periodo_inicio, null: false
      t.date :periodo_fin, null: false
      t.string :metodo, null: false
      t.references :registrado_por, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
