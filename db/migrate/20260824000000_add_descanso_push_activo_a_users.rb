# Push del rest-timer (Fase 20e): opt-in aparte del de racha — por defecto
# APAGADO (a diferencia de wake_lock_activo), un push por descanso es más
# intrusivo que mantener la pantalla prendida y no hay por qué asumir que
# se quiere. Mismo patrón booleano que wake_lock_activo/vip.
class AddDescansoPushActivoAUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :descanso_push_activo, :boolean, null: false, default: false
  end
end
