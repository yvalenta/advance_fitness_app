# Job recurrente diario (config/recurring.yml, Fase 6.9): activa las
# suscripciones "programadas" (incluidas con una membresía combo) cuyo turno
# ya llegó, tomando el lugar de la que tenía el usuario antes.
class ActivarSuscripcionesProgramadasJob < ApplicationJob
  queue_as :default

  def perform
    Suscripcion.activar_programadas!
  end
end
