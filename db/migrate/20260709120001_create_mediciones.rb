class CreateMediciones < ActiveRecord::Migration[8.1]
  # Antropometría completa (SDD §07, Fase 5.9): capturada por el staff con
  # historial y alimenta el prompt de IA de la suscripción; el miembro también
  # auto-registra su peso. IMC como columna generada de Postgres.
  def change
    create_table :mediciones do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tomada_por, null: true, foreign_key: { to_table: :users }
      t.date :fecha, null: false

      t.decimal :peso_kg, precision: 5, scale: 2
      t.decimal :talla_cm, precision: 5, scale: 1
      t.virtual :imc, type: :decimal, precision: 4, scale: 1, stored: true,
                as: "ROUND((peso_kg / ((NULLIF(talla_cm, 0) / 100.0) ^ 2))::numeric, 1)"
      t.decimal :grasa_pct, precision: 4, scale: 1

      # Perímetros (cm)
      %i[cuello_cm pecho_cm cintura_cm cadera_cm brazo_cm muslo_cm pantorrilla_cm].each do |columna|
        t.decimal columna, precision: 5, scale: 1
      end
      # Diámetros óseos (cm)
      %i[muneca_cm codo_cm rodilla_cm].each { |columna| t.decimal columna, precision: 4, scale: 1 }
      # Pliegues cutáneos (mm)
      %i[pliegue_tricipital_mm pliegue_subescapular_mm pliegue_suprailiaco_mm
         pliegue_abdominal_mm pliegue_muslo_mm].each { |columna| t.decimal columna, precision: 4, scale: 1 }

      t.text :notas
      t.timestamps
    end

    add_index :mediciones, [ :user_id, :fecha ], unique: true
  end
end
