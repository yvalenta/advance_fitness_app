# Puente entre los controllers y el motor de juego (Fase 14.12): UN job por
# evento (check-in o primer ejercicio marcado del día), jamás por ejercicio
# individual — el pooler de Supabase aguanta 15 conexiones. Idempotente
# extremo a extremo: los reintentos de ApplicationJob chocan con la
# constraint única del ledger y terminan en no-op.
class OtorgarPuntosJob < ApplicationJob
  queue_as :background

  # El origen viaja como GlobalID string (no como record serializado) para
  # que el argumento sobreviva en la cola; si al ejecutar el origen ya no
  # existe, no hay puntos que otorgar.
  def perform(user_id, tipo:, fecha:, origen_gid: nil)
    user = User.find_by(id: user_id)
    return if user.nil?

    origen = origen_gid && GlobalID::Locator.locate(origen_gid)
    Juego::Otorgador.otorgar!(user, tipo: tipo, fecha: fecha, origen: origen)
    Juego::Racha.actualizar!(user, fecha: fecha) if tipo.in?(Juego::Recalculador::TIPOS_ACTIVIDAD)
  rescue ActiveRecord::RecordNotFound
    nil # el origen fue borrado antes de correr el job
  end
end
