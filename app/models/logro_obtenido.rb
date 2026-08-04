# Logro conseguido por un miembro (Fase 14.12). `contexto` guarda el detalle
# del momento (p. ej. el PR o la racha que lo disparó). Único por
# (user, logro): un logro se obtiene una sola vez — refuerzo en DB.
class LogroObtenido < ApplicationRecord
  belongs_to :user
  belongs_to :logro

  validates :obtenido_en, presence: true
  validates :logro_id, uniqueness: { scope: :user_id }
end
