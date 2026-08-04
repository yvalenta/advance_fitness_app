# Motor de juego (Fase 14.12), cuatro tablas y una regla: `registros_puntos`
# es LA fuente de verdad (ledger append-only); `perfiles_juego` es una
# proyección reconstruible (Juego::Recalculador); `logros` es catálogo
# (tenant nil = global, patrón de Ejercicio) y `logros_obtenidos` el vínculo.
class CrearMotorDeJuego < ActiveRecord::Migration[8.1]
  def change
    create_table :registros_puntos do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :tipo, null: false
      t.integer :puntos, null: false
      t.date :fecha, null: false
      t.string :origen_tipo
      t.bigint :origen_id
      t.references :creado_por, foreign_key: { to_table: :users }
      t.datetime :created_at, null: false
    end

    # CRÍTICA: ApplicationJob reintenta hasta 5 veces ante
    # ConnectionNotEstablished (ventana de deploy con el pooler de Supabase);
    # sin esta constraint, cada reintento de OtorgarPuntosJob duplicaría
    # puntos. Parcial porque los ajustes manuales no llevan origen.
    add_index :registros_puntos, [ :user_id, :tipo, :origen_tipo, :origen_id ],
              unique: true, where: "origen_id IS NOT NULL",
              name: "index_registros_puntos_origen_unico"
    add_index :registros_puntos, [ :user_id, :fecha ]
    add_index :registros_puntos, :fecha

    create_table :perfiles_juego do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      # Desnormalizado vía TenantDesnormalizado (hereda_tenant_de :user):
      # el leaderboard filtra por columna, sin join. Nullable para que un
      # rollback no falle (§16.7); la coherencia la exige el modelo.
      t.references :tenant, foreign_key: true, index: false
      t.integer :puntos_total, null: false, default: 0
      t.integer :nivel, null: false, default: 1
      t.integer :racha_actual, null: false, default: 0
      t.integer :racha_mejor, null: false, default: 0
      t.date :ultima_fecha_racha
      t.integer :logros_count, null: false, default: 0
      t.boolean :visible_en_tabla, null: false, default: false
      t.string :apodo
      t.timestamps
    end

    # El futuro leaderboard: WHERE tenant + visible ORDER BY puntos, directo
    # del índice.
    add_index :perfiles_juego, [ :tenant_id, :visible_en_tabla, :puntos_total ]

    create_table :logros do |t|
      t.string :codigo, null: false
      t.string :nombre, null: false
      t.string :descripcion
      t.string :icono
      t.integer :puntos, null: false, default: 0
      t.string :categoria, null: false
      t.boolean :activo, null: false, default: true
      t.references :tenant, foreign_key: true # nil = catálogo global
      t.references :creado_por, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :logros, :codigo, unique: true

    create_table :logros_obtenidos do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :logro, null: false, foreign_key: true
      t.datetime :obtenido_en, null: false
      t.jsonb :contexto, null: false, default: {}
      t.timestamps
    end

    add_index :logros_obtenidos, [ :user_id, :logro_id ], unique: true
  end
end
