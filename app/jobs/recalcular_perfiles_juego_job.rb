# Red de seguridad nocturna del motor de juego (Fase 14.12): reconstruye la
# proyección de los users con movimiento en el ledger en las últimas 24h
# (config/recurring.yml, 4:10am). Si un job perdido o un bug dejó
# `perfiles_juego` desfasado del ledger, aquí se corrige solo.
class RecalcularPerfilesJuegoJob < ApplicationJob
  queue_as :background

  def perform
    user_ids = RegistroPunto.where(created_at: 24.hours.ago..).distinct.pluck(:user_id)
    User.where(id: user_ids).find_each { |user| Juego::Recalculador.para(user) }
  end
end
