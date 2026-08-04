# Preferencia de tema del miembro (Fase 16, SDD Nota 21): oscuro (default),
# claro, o sistema (sigue al SO). Preferencia de la PERSONA, no del tenant —
# el branding del tenant (paleta_colores) es ortogonal y aplica en ambos.
class AddTemaAUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :tema, :string, null: false, default: "oscuro"
  end
end
