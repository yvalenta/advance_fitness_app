# Push del rest-timer (Fase 20e): DescansoPushController lo encola con
# `wait:` al momento exacto en que faltan los segundos del cronómetro,
# junto con el token vigente en ese instante (users.descanso_push_token).
# Al ejecutarse, si el token ya no coincide (se programó otro más reciente,
# o el miembro volvió a la pestaña antes de tiempo y lo canceló) es un
# no-op — mismo patrón de idempotencia que `racha_recordada_en`. No se
# valida contra el job real de Solid Queue: esa tabla solo existe en
# producción (queue_adapter :solid_queue únicamente ahí), así que la única
# forma de "cancelar" que funciona en todos los entornos es esta.
class NotificarDescansoJob < ApplicationJob
  queue_as :background

  def perform(user_id, mensaje, token)
    return if ENV["VAPID_PRIVATE_KEY"].blank?

    user = User.find_by(id: user_id)
    return unless user&.descanso_push_activo?
    return if token.blank? || user.descanso_push_token != token

    user.update!(descanso_push_token: nil)
    user.suscripciones_push.each do |suscripcion|
      Notificaciones::EnviadorPush.enviar(suscripcion, titulo: "⏱️ Tu tiempo terminó", cuerpo: mensaje,
                                          url: "/sesion", tag: "descanso")
    end
  end
end
