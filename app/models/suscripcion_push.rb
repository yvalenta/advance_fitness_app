# Dispositivo suscrito a Web Push (Fase 15, SDD Nota 20): el endpoint que
# emite el push service del navegador + las llaves de cifrado del payload.
# Solo-dueño: la policy no tiene rama de staff. El payload que se envía por
# aquí jamás lleva datos de salud (regla de producto, Nota 20c).
class SuscripcionPush < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh, presence: true
  validates :auth, presence: true

  # Upsert por endpoint: el navegador puede re-suscribirse (rotación del
  # push service) o el mismo dispositivo cambiar de cuenta — la fila sigue
  # al endpoint, que es la identidad real del dispositivo.
  def self.registrar!(user, endpoint:, p256dh:, auth:, user_agent: nil)
    suscripcion = find_or_initialize_by(endpoint: endpoint)
    suscripcion.update!(user: user, p256dh: p256dh, auth: auth, user_agent: user_agent)
    suscripcion
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
