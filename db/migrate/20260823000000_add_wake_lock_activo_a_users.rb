# Wake Lock (Fase 19d): pantalla activa mientras corre el modo sesión —
# apagable en Ajustes. Mismo patrón booleano que `vip`: default encendido,
# el miembro lo desactiva si le molesta (algunos móviles se calientan).
class AddWakeLockActivoAUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :wake_lock_activo, :boolean, null: false, default: true
  end
end
