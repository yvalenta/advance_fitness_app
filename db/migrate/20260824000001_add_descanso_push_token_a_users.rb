# Push del rest-timer (Fase 20e) — token de vigencia, no el job de Solid
# Queue: `SolidQueue::Job` vive en una base lógica que solo existe en
# producción (`config.active_job.queue_adapter = :solid_queue` está SOLO en
# production.rb; dev/test usan :async/:test y jamás provisionan
# solid_queue_jobs), así que "cancelar" no puede ser "buscar y descartar el
# job real" — sería inalcanzable fuera de producción. En su lugar, el job
# se programa con ESTE token; al ejecutarse compara contra el vigente y es
# no-op si no coincide (se invalidó al programar otro, o al volver a la
# pestaña) — el mismo patrón de `racha_recordada_en` para la idempotencia.
class AddDescansoPushTokenAUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :descanso_push_token, :string
  end
end
