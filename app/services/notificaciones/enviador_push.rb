module Notificaciones
  # Envía un push cifrado a UN dispositivo (Fase 15, SDD Nota 20). El payload
  # es mínimo — { titulo, cuerpo, url, tag } — y JAMÁS lleva datos de salud:
  # el transporte pasa por el push service del navegador (FCM/Mozilla/APNs)
  # como relay, y aunque va cifrado extremo a extremo, la regla es de
  # producto, no técnica. Si el push service responde que el endpoint ya no
  # existe (410 Gone / 404), la suscripción se borra: auto-depuración.
  class EnviadorPush
    def self.enviar(suscripcion, titulo:, cuerpo:, url: "/", tag: nil)
      return false if ENV["VAPID_PRIVATE_KEY"].blank?

      WebPush.payload_send(
        message: JSON.generate({ titulo: titulo, cuerpo: cuerpo, url: url, tag: tag }.compact),
        endpoint: suscripcion.endpoint,
        p256dh: suscripcion.p256dh,
        auth: suscripcion.auth,
        vapid: {
          subject: sujeto,
          public_key: ENV["VAPID_PUBLIC_KEY"],
          private_key: ENV["VAPID_PRIVATE_KEY"]
        }
      )
      true
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
      suscripcion.destroy!
      false
    rescue WebPush::ResponseError => e
      # Transitorio (429, 5xx del push service): se pierde este aviso, el
      # dispositivo sigue suscrito para el de mañana. Sin reintento propio.
      Rails.logger.warn("[web-push] #{e.class} en suscripción #{suscripcion.id}")
      false
    end

    # VAPID exige un contacto del operador; en producción es el host real.
    def self.sujeto
      ENV["APP_HOST"].present? ? "https://#{ENV["APP_HOST"]}" : "mailto:dev@localhost"
    end
  end
end
