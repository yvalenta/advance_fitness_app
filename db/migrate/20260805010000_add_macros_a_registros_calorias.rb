# Macros del consumo real del día (Fase 14.4): los gramos que el miembro
# marcó desde el checklist de su plan nutricional. NULL = sin dato (un
# registro manual de solo kcal no sabe de macros); no confundir con 0 g.
# Reversible: add_column puro dentro de `change`.
class AddMacrosARegistrosCalorias < ActiveRecord::Migration[8.1]
  def change
    add_column :registros_calorias, :proteinas_g, :integer
    add_column :registros_calorias, :carbohidratos_g, :integer
    add_column :registros_calorias, :grasas_g, :integer
  end
end
