# Ciclo menstrual (Fase 14.15) — dato de salud SENSIBLE. La tabla guarda lo
# mínimo (fechas, duración del sangrado y una nota opcional) y se aísla POR
# PERSONA: a diferencia de todo el resto del dominio, ni el staff del propio
# tenant ve estas filas (CicloMenstrualPolicy no tiene rama de staff). La
# fase del ciclo se DERIVA al consultar (Ciclo::Fase) y jamás se persiste —
# mismo principio que User#edad. Los datos solo existen mientras el
# consentimiento `ciclo_menstrual` (Fase 14.11) esté vigente: al revocarlo
# sin "conservar mis datos" se borran físicamente (CicloMenstrual.revocar!).
class CrearCiclosMenstruales < ActiveRecord::Migration[8.1]
  def change
    create_table :ciclos_menstruales do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.date :fecha_inicio, null: false
      t.date :fecha_fin
      t.integer :duracion_sangrado_dias
      t.text :nota
      # Auditoría mínima: siempre es la propia usuaria (la policy no deja a
      # nadie más crear), pero el rastro de autoría queda explícito.
      t.references :creado_por, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    # Único: un inicio de ciclo por (usuaria, fecha). El mismo índice
    # compuesto cubre las lecturas ordenadas — Postgres lo recorre hacia
    # atrás para el ORDER BY fecha_inicio DESC — así que no hace falta un
    # segundo índice, y por eso `references :user` no crea el suyo propio.
    add_index :ciclos_menstruales, [ :user_id, :fecha_inicio ], unique: true
  end
end
