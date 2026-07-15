class Novedad < ApplicationRecord
  validates :titulo, :contenido, presence: true

  scope :publicadas, -> { where(publicado: true).order(fecha_evento: :asc, created_at: :desc) }
end
