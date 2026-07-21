# Un tenant = un gimnasio/entrenador/influencer con su propio subdominio
# `{slug}.ynt.codes` (SDD §16.6, row-level tenancy por subdominio). Los
# subdominios reservados protegen el portal comercial y el host de back-
# compat de Advance Fitness. Los precios/duración por tenant son opcionales:
# si están vacíos, Negocio.* cae al ENV/YAML global.
class Tenant < ApplicationRecord
  TIPOS = %w[gimnasio entrenador influencer].freeze
  SUBDOMINIOS_RESERVADOS = %w[comercial app www api advance-fitness-app admin].freeze

  has_many :users, dependent: :restrict_with_error
  has_many :posts, dependent: :destroy
  has_many :novedades, dependent: :destroy
  has_one_attached :logo

  before_validation :normalizar_slug

  validates :nombre, :email_contacto, presence: true
  validates :tipo_entidad, inclusion: { in: TIPOS }
  validates :slug, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9][a-z0-9-]*\z/ },
            exclusion: { in: SUBDOMINIOS_RESERVADOS }

  scope :activos, -> { where(activo: true) }

  def gimnasio? = tipo_entidad == "gimnasio"

  # Membresías se muestran solo a gimnasios (o a un tenant no-gimnasio que las
  # habilite explícitamente). Un tenant sin la clave (jsonb {}) queda cubierto
  # por gimnasio? — para entrenador/influencer el default es apagado.
  def membresias_habilitadas?
    if features_habilitadas.key?("membresias")
      features_habilitadas["membresias"] != false
    else
      gimnasio?
    end
  end

  private
    def normalizar_slug
      return if slug.blank?
      self.slug = slug.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    end
end
