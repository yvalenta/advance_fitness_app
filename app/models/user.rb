class User < ApplicationRecord
  ROLES = %w[miembro entrenador admin].freeze
  SOMATOTIPOS = %w[ectomorfo mesomorfo endomorfo].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one :membresia, dependent: :destroy
  has_many :accesos, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :rol, inclusion: { in: ROLES }
  validates :sexo, inclusion: { in: %w[M F] }, allow_nil: true
  validates :somatotipo, inclusion: { in: SOMATOTIPOS }, allow_nil: true
  validates :talla_cm, numericality: { greater_than: 0 }, allow_nil: true
  validates :nivel_actividad, numericality: { in: 1.2..1.9 }, allow_nil: true

  def staff? = rol.in?(%w[entrenador admin])
  def admin? = rol == "admin"
  def entrenador? = rol == "entrenador"

  # Login con Google: encuentra o crea el usuario por email verificado.
  # Los usuarios creados vía OAuth reciben un password aleatorio (pueden
  # fijar el suyo luego con el flujo de reset).
  def self.from_omniauth(auth)
    find_or_create_by!(email_address: auth.info.email) do |user|
      user.nombre = auth.info.name.to_s
      user.password = SecureRandom.base58(32)
    end
  end
end
