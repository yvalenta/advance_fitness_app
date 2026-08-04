# Catálogo de logros del motor de juego (Fase 14.12). `tenant_id` nil =
# logro GLOBAL del catálogo base (sembrado por db/seeds.rb, mismo patrón que
# el catálogo `Ejercicio`); con tenant = logro propio de ese gimnasio.
class Logro < ApplicationRecord
  CATEGORIAS = %w[constancia fuerza nutricion social].freeze

  belongs_to :tenant, optional: true
  belongs_to :creado_por, class_name: "User", optional: true
  has_many :logros_obtenidos, class_name: "LogroObtenido", dependent: :destroy

  validates :codigo, presence: true, uniqueness: true
  validates :nombre, presence: true
  validates :puntos, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :categoria, inclusion: { in: CATEGORIAS }

  scope :activos, -> { where(activo: true) }

  def global? = tenant_id.nil?
end
