# Job recurrente diario (config/recurring.yml): marca como vencida toda
# membresía activa cuyo vencimiento ya pasó (SDD §09).
class VencerMembresiasJob < ApplicationJob
  queue_as :default

  def perform
    Membresia.para_vencer.find_each do |membresia|
      membresia.update!(estado: "vencida")
    end
  end
end
