# Recordatorio de racha (Fase 15, SDD Nota 20): a las 6pm, quien tiene la
# racha viva pero aún no entrena HOY recibe un push en sus dispositivos
# suscritos. Elegible = ultima_fecha_racha == AYER (quien ya entrenó hoy no
# se molesta; quien ya la perdió no recibe culpa). Idempotente por
# `racha_recordada_en`: se marca ANTES de enviar — ante un reintento del
# job (retry_on de ApplicationJob) preferimos perder un aviso a duplicarlo.
class RecordatorioRachaJob < ApplicationJob
  queue_as :background

  def perform
    return if ENV["VAPID_PRIVATE_KEY"].blank?

    elegibles.find_each do |perfil|
      perfil.update!(racha_recordada_en: Date.current)
      dias = perfil.racha_actual
      perfil.user.suscripciones_push.each do |suscripcion|
        Notificaciones::EnviadorPush.enviar(
          suscripcion,
          titulo: "🔥 Tu racha sigue viva",
          cuerpo: "Racha de #{dias} #{"día".pluralize(dias)} en juego. Un entrenamiento hoy la mantiene encendida.",
          url: "/",
          tag: "racha"
        )
      end
    end
  end

  private

  # Solo perfiles con al menos un dispositivo suscrito (join + distinct) y
  # no recordados hoy — Date.current respeta America/Bogota (config.time_zone).
  def elegibles
    PerfilJuego.joins(user: :suscripciones_push)
               .where(ultima_fecha_racha: Date.current - 1)
               .where(racha_actual: 1..)
               .where("racha_recordada_en IS NULL OR racha_recordada_en < ?", Date.current)
               .includes(user: :suscripciones_push)
               .distinct
  end
end
