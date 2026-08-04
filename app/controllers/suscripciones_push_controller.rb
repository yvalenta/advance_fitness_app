# Suscripción Web Push del dispositivo actual (Fase 15, SDD Nota 20).
# Siempre en primera persona: el dueño es Current.user y la identidad del
# recurso es el endpoint que envía el propio navegador — no se acepta id
# ni user_id. El JSON llega del push_controller de Stimulus.
class SuscripcionesPushController < ApplicationController
  # Upsert por endpoint: re-suscribirse (rotación del push service) o
  # cambiar de cuenta en el mismo navegador actualiza la fila, no duplica.
  def create
    authorize SuscripcionPush.new(user: Current.user)
    SuscripcionPush.registrar!(Current.user,
                               endpoint: params.require(:endpoint),
                               p256dh: params.require(:p256dh),
                               auth: params.require(:auth),
                               user_agent: request.user_agent)
    head :created
  end

  # Idempotente: quitar un endpoint ya borrado (o de otra persona, que el
  # scope solo-dueño vuelve invisible) responde el mismo 204.
  def destroy
    suscripcion = policy_scope(SuscripcionPush).find_by(endpoint: params[:endpoint])
    authorize suscripcion || SuscripcionPush.new(user: Current.user)
    suscripcion&.destroy!
    head :no_content
  end
end
