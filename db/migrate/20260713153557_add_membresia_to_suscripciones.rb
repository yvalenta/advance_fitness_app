class AddMembresiaToSuscripciones < ActiveRecord::Migration[8.1]
  def change
    # Presente solo en la suscripción $0 que se incluye automáticamente al
    # pagar la membresía por $350.000 (Fase 6.9) — enlaza a esa membresía y
    # marca que "no es una compra aparte".
    add_reference :suscripciones, :membresia, null: true, foreign_key: true
  end
end
