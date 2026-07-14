# Registro cuantitativo de fuerza (series/reps/peso/RPE) por sesión de
# entrenamiento — la base de datos del Analista de Performance (SDD §18).
# Convive con el JSONB de checkboxes de `registros_entrenamiento.ejercicios`,
# que sigue siendo solo el "marcar hecho" de la UI del plan.
class CreateDetalleEntrenamientos < ActiveRecord::Migration[8.1]
  def change
    create_table :detalle_entrenamientos do |t|
      t.references :registro_entrenamiento, null: false, foreign_key: { on_delete: :cascade }
      t.references :ejercicio, null: false, foreign_key: true
      t.integer :serie, null: false
      t.integer :repeticiones, null: false
      # NULL = ejercicio a peso corporal (calistenia), sin carga externa
      t.decimal :peso_kg, precision: 6, scale: 2
      t.integer :rpe
      t.text :notas

      t.timestamps
    end

    # Progresión por ejercicio (¿cómo evoluciona el press de banca del usuario?)
    add_index :detalle_entrenamientos, [ :ejercicio_id, :registro_entrenamiento_id ],
              name: "index_detalles_on_ejercicio_y_registro"
    # Una fila por serie de un ejercicio en una sesión: el registro es idempotente
    add_index :detalle_entrenamientos, [ :registro_entrenamiento_id, :ejercicio_id, :serie ],
              unique: true, name: "index_detalles_unicos_por_serie"
  end
end
