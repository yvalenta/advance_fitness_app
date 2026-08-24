# Reprogramar un día (Fase 19e): mueve el ENTRENAMIENTO de una fecha a otra
# sin tocar la plantilla semanal del plan (`rutina.dias`) — un miembro que
# falta un día lo corre a otro sin perder su semana. Vive aparte del JSONB
# de la rutina, mismo criterio que el resto del dominio: una excepción por
# fecha es un hecho auditable, no una edición de la plantilla.
class CrearReprogramacionesDia < ActiveRecord::Migration[8.1]
  def change
    create_table :reprogramaciones_dia do |t|
      t.references :plan_personalizado, null: false, foreign_key: true
      t.date :fecha_original, null: false
      t.date :fecha_destino, null: false

      t.timestamps
    end

    # Un origen solo puede apuntar a un destino (upsert, no duplicados) y un
    # destino solo puede recibir el contenido de un origen (sin ambigüedad
    # sobre qué día se está mostrando).
    add_index :reprogramaciones_dia, [ :plan_personalizado_id, :fecha_original ], unique: true, name: "index_reprogramaciones_por_origen"
    add_index :reprogramaciones_dia, [ :plan_personalizado_id, :fecha_destino ], unique: true, name: "index_reprogramaciones_por_destino"
  end
end
