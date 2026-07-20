# Job recurrente diario (config/recurring.yml): marca como expirada toda
# suscripción activa cuya fecha_fin ya pasó (Fase 12.2). VIP queda excluida
# por Suscripcion.para_vencer.
class VencerSuscripcionesJob < ApplicationJob
  queue_as :default

  def perform
    Suscripcion.para_vencer.find_each do |suscripcion|
      suscripcion.update!(estado: "expirada")
    end
  end
end
