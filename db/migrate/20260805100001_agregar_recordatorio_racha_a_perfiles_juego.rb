# Idempotencia del recordatorio de racha (Fase 15): RecordatorioRachaJob
# marca aquí la fecha del último aviso — un reintento del job recurrente
# (retry_on de ApplicationJob) no vuelve a notificar el mismo día.
class AgregarRecordatorioRachaAPerfilesJuego < ActiveRecord::Migration[8.1]
  def change
    add_column :perfiles_juego, :racha_recordada_en, :date
  end
end
