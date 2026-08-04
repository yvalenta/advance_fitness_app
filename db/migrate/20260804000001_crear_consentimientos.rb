# Consentimientos versionados (Fase 14.11): bloquean la tabla de posiciones
# del motor de juego y el futuro módulo de ciclo. Append-only con el mismo
# espíritu auditable que `pagos` (se deja rastro, jamás se borra): sin
# updated_at, sin edición. La vigencia NO se guarda en una columna — es la
# última fila por (user, tipo), de ahí el índice compuesto (que además cubre
# el prefijo user_id, por eso `references` no crea su índice propio).
class CrearConsentimientos < ActiveRecord::Migration[8.1]
  def change
    create_table :consentimientos do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :tipo, null: false
      t.string :accion, null: false
      t.string :version_texto, null: false
      t.string :ip
      t.string :user_agent
      t.datetime :created_at, null: false
    end

    add_index :consentimientos, [ :user_id, :tipo, :created_at ]
  end
end
