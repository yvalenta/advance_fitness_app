# Enlaza la biblioteca curada del entrenador con el catálogo visual (Fase
# 6.4): la plantilla hereda el GIF/instrucciones de su ejercicio del dataset.
class AddEjercicioAPlantillasEjercicio < ActiveRecord::Migration[8.1]
  def change
    add_reference :plantillas_ejercicio, :ejercicio, null: true, foreign_key: true
  end
end
