# Push del rest-timer (Fase 20e, SDD Nota 27): programa/cancela UN aviso
# retrasado — sesion_controller.js lo llama solo cuando el miembro deja la
# pestaña con un cronómetro corriendo (visibilitychange), y lo cancela si
# vuelve antes de tiempo. La "cancelación" es un token en users, no el job
# real de Solid Queue (ver NotificarDescansoJob). Siempre en primera
# persona, mismo criterio que SuscripcionesPushController.
class DescansoPushController < ApplicationController
  # Sin registro que autorizar (como ProgresoController): es una acción
  # sobre el propio Current.user, no sobre un modelo.
  def create
    skip_authorization
    elegible = Current.user.descanso_push_activo? && Current.user.suscripciones_push.exists?
    return render json: { token: nil } unless elegible

    segundos = params[:segundos].to_i.clamp(1, 900)
    mensaje = params[:mensaje].to_s.strip.presence || "Tu tiempo terminó"
    token = SecureRandom.hex(8)
    Current.user.update!(descanso_push_token: token)
    NotificarDescansoJob.set(wait: segundos.seconds).perform_later(Current.user.id, mensaje, token)
    render json: { token: token }
  end

  # Idempotente: cancelar sin nada pendiente, o un token ya superado por
  # uno más nuevo, no rompe nada — solo limpia el vigente.
  def destroy
    skip_authorization
    Current.user.update!(descanso_push_token: nil)
    head :no_content
  end
end
