class Post < ApplicationRecord
  belongs_to :autor, class_name: "User"
  has_rich_text :contenido

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
