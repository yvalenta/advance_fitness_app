class Novedad < ApplicationRecord
  # Aislada por tenant_id directo (SDD §16.6; controllers vía policy_scope —
  # Fase 18f). optional: la columna es nullable por rollback, igual que §16.7.
  belongs_to :tenant, optional: true

  validates :titulo, :contenido, presence: true

  scope :publicadas, -> { where(publicado: true).order(fecha_evento: :asc, created_at: :desc) }
end
