# Fase de Calidad: índices single-column redundantes — cada uno está cubierto
# por un índice compuesto con la misma columna como líder, así que solo
# añadían overhead de escritura. Confirmado contra pg_stat de producción
# (advisor "unused_index" de Supabase, julio 2026). NO se toca
# suscripciones.user_id: su otro índice de user_id es parcial
# (WHERE estado='activa') y no cubre búsquedas generales.
class EliminarIndicesRedundantes < ActiveRecord::Migration[8.1]
  def change
    remove_index :accesos, :user_id                                      # cubre (user_id, fecha_hora)
    remove_index :mediciones, :user_id                                   # cubre (user_id, fecha)
    remove_index :registros_calorias, :user_id                           # cubre (user_id, fecha)
    remove_index :registros_entrenamiento, :user_id                      # cubre (user_id, fecha)
    remove_index :planes_personalizados, :user_id                        # cubre (user_id, estado)
    remove_index :detalle_entrenamientos, :registro_entrenamiento_id     # cubre el unique (registro, ejercicio, serie)
    remove_index :detalle_entrenamientos, :ejercicio_id                  # cubre (ejercicio_id, registro_entrenamiento_id)
  end
end
