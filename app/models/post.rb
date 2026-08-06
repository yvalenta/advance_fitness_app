class Post < ApplicationRecord
  include TenantDesnormalizado

  belongs_to :autor, class_name: "User"
  # Aislado por tenant_id directo (SDD §16.6, Fase 18f): hereda el tenant del
  # autor y rechaza cualquier fila incoherente.
  hereda_tenant_de :autor
  has_rich_text :contenido
  has_one_attached :portada

  validates :titulo, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "solo minúsculas, números y guiones" }

  scope :publicados, -> { where(publicado: true).order(publicado_en: :desc) }

  before_validation :generar_slug, on: :create

  def publicar! = update!(publicado: true, publicado_en: Time.current)

  private
    def generar_slug
      self.slug = titulo.to_s.parameterize if slug.blank? && titulo.present?
    end
end
