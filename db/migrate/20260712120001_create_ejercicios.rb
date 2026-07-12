# Catálogo visual de ejercicios (SDD Fase 6.1), importado del dataset abierto
# hasaneyldrm/exercises-dataset: 1.324 ejercicios con instrucciones en español
# y media (GIF + imagen 180×180) © Gym Visual, con atribución obligatoria.
class CreateEjercicios < ActiveRecord::Migration[8.1]
  def change
    create_table :ejercicios do |t|
      t.string :dataset_id, null: false            # "0001" — id del dataset origen
      t.string :nombre, null: false                # español, editable por el staff
      t.string :nombre_en, null: false             # original del dataset, inmutable
      t.string :nombre_normalizado, null: false    # sin acentos/downcase, para fallback por nombre
      t.string :musculo, null: false               # enum de PlantillaEjercicio (pecho, espalda…)
      t.string :categoria, null: false             # body_part original (back, cardio, chest…)
      t.string :equipo                             # equipment (barbell, body weight…)
      t.string :objetivo                           # target muscle (biceps, abs…)
      t.jsonb :musculos_secundarios, default: [], null: false
      t.jsonb :instrucciones, default: [], null: false # pasos en español
      t.string :imagen_ruta                        # "images/0001-2gPfomN.jpg"
      t.string :gif_ruta                           # "videos/0001-2gPfomN.gif"
      t.string :atribucion, null: false, default: "© Gym visual"

      t.timestamps
    end

    add_index :ejercicios, :dataset_id, unique: true
    add_index :ejercicios, :musculo
    add_index :ejercicios, :nombre_normalizado
  end
end
