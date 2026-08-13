# Leads del canal de autoservicio en join.ynt.codes (Fase 12a, SDD §17.5):
# entrenadores y personas individuales piden entrar sin pasar por el
# comercializador. Cobro manual todavía — esta tabla es la cola que el staff
# del portal comercial revisa y cierra a mano (WhatsApp/llamada), no un
# aprovisionamiento automático.
class CrearSolicitudesAutoservicio < ActiveRecord::Migration[8.1]
  def change
    create_table :solicitudes_autoservicio do |t|
      t.string :nombre, null: false
      t.string :email, null: false
      t.string :telefono, null: false
      # entrenador | individual (SolicitudAutoservicio::SEGMENTOS)
      t.string :segmento, null: false
      t.string :negocio_nombre
      t.text :mensaje
      # Atendida = el comercializador ya contactó al lead y cerró (o descartó)
      # la venta a mano. Nunca se borra — es el historial de leads del canal.
      t.datetime :atendida_en
      t.references :atendida_por, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :solicitudes_autoservicio, :segmento
    add_index :solicitudes_autoservicio, :atendida_en
  end
end
