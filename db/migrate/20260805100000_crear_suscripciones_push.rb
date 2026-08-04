# Suscripciones Web Push (Fase 15, SDD Nota 20): una fila por dispositivo
# del miembro (endpoint del push service + llaves de cifrado del navegador).
# Solo-dueño como el ciclo: el staff no lista ni toca dispositivos ajenos.
# El parque se auto-depura: EnviadorPush borra la fila ante 410/404.
class CrearSuscripcionesPush < ActiveRecord::Migration[8.1]
  def change
    create_table :suscripciones_push do |t|
      t.references :user, null: false, foreign_key: true
      # El endpoint es la identidad del dispositivo (URL única que emite el
      # push service del navegador). Único global: si el mismo navegador se
      # re-suscribe con otra cuenta, la fila cambia de dueño (upsert).
      t.text :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.string :user_agent
      t.timestamps
    end

    add_index :suscripciones_push, :endpoint, unique: true
  end
end
