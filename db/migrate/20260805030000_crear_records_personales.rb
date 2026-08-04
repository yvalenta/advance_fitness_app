# Récords personales (Fase 14.13): la mejor marca por (user, ejercicio, tipo).
# Historial, no bitácora efímera: el PR superado no se borra — se le marca
# `superado_en` (patrón pagos.anulado_en) y el índice único parcial garantiza
# que solo haya UN vigente por marca.
class CrearRecordsPersonales < ActiveRecord::Migration[8.1]
  def change
    create_table :records_personales do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :ejercicio, null: false, foreign_key: true
      # peso_max / volumen_max / reps_max (RecordPersonal::TIPOS)
      t.string :tipo, null: false
      t.decimal :valor, precision: 8, scale: 2, null: false
      t.integer :repeticiones
      t.decimal :peso_kg, precision: 6, scale: 2
      t.date :fecha, null: false
      # La serie que produjo la marca. on_delete: :nullify — quitar la serie
      # (destroy del dueño en el dialog) no puede arrastrarse el récord.
      t.references :detalle_entrenamiento, foreign_key: { on_delete: :nullify }
      t.datetime :superado_en
      # true para la primera marca de un (user, ejercicio, tipo): es la vara
      # a batir, no un récord — sin puntos ni celebración (evita la lluvia
      # de "PRs" el día 1).
      t.boolean :baseline, null: false, default: false
      t.timestamps
    end

    # EL invariante: un solo PR vigente por marca. Parcial para que el
    # historial de superados pueda crecer sin límite.
    add_index :records_personales, [ :user_id, :ejercicio_id, :tipo ],
              unique: true, where: "superado_en IS NULL",
              name: "index_records_personales_vigente"
    add_index :records_personales, [ :user_id, :fecha ]
  end
end
