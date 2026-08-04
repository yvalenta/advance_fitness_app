# Acento personalizado del miembro (Fase 17, Nota 22f): volt (default,
# sigue la marca del tenant), ámbar o azul. Con los gradientes ya
# parametrizados por var() (Fase 16.2), un acento es solo overrides de
# --color-volt* en la sesión propia.
class AddAcentoAUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :acento, :string, null: false, default: "volt"
  end
end
