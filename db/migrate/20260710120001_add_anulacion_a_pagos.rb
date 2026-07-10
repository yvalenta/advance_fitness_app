class AddAnulacionAPagos < ActiveRecord::Migration[8.1]
  # Fase 5.11: el historial de pagos pasa de inmutable a AUDITABLE — un pago se
  # corrige (monto/método) o se anula dejando rastro; nunca se borra físicamente.
  def change
    add_column :pagos, :anulado_en, :datetime
    add_reference :pagos, :anulado_por, foreign_key: { to_table: :users }
  end
end
