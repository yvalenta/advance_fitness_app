# Análisis con IA del historial cuantitativo de un miembro (SDD §18, Fase
# 11-B): una fila por sesión (RegistroEntrenamiento) desde la que se disparó
# el análisis, aunque el contenido resume la tendencia real (últimas ~20
# series de cualquier ejercicio/sesión), no solo el día puntual.
class CreateFeedbackIa < ActiveRecord::Migration[8.1]
  def change
    create_table :feedback_ia do |t|
      t.references :registro_entrenamiento, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      # Ciclo de vida del job (distinto del campo de negocio "diagnostico")
      t.string :estado, null: false, default: "pendiente"
      # Salida del prompt del Analista de Performance (SDD §18.4)
      t.string :diagnostico
      t.text :analisis
      t.text :accion_recomendada
      t.string :modelo
      t.text :error
      t.integer :intentos, null: false, default: 0

      t.timestamps
    end
  end
end
