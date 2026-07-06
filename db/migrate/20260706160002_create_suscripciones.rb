class CreateSuscripciones < ActiveRecord::Migration[8.1]
  def change
    create_table :suscripciones do |t|
      t.references :user, null: false, foreign_key: true
      t.references :plan, null: false, foreign_key: { to_table: :planes }
      t.string :estado, null: false, default: "activa"
      t.date :fecha_inicio, null: false
      t.date :fecha_fin

      t.timestamps
    end

    # Solo una suscripción activa por usuario
    add_index :suscripciones, :user_id, unique: true, where: "estado = 'activa'",
              name: "index_suscripciones_una_activa_por_user"
  end
end
